from __future__ import annotations
# distutils: language=c
# cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True

from libc.stdlib cimport malloc, free
from pathlib import Path


def unlzw(inp: Path | bytes) -> bytes:
    """
    Decompress Unix compress .Z files using LZW compression.
    Adapted for Cython from Python implementation.
    """
    cdef unsigned char *ba_in
    cdef unsigned int inlen, i
    cdef unsigned short *prefix
    cdef unsigned short *suffix
    cdef unsigned int bits, mask, max_, flags, end, rem
    cdef unsigned int buf, left, prev, final, code, temp, mark, nxt
    cdef unsigned int *stack
    cdef unsigned int stack_ptr = 0
    cdef bytearray output
    cdef unsigned int output_len = 0

    # Input handling
    if isinstance(inp, Path):
        ba_temp = bytearray(inp.read_bytes())
    else:
        ba_temp = bytearray(inp)

    # Convert input data stream to byte array, and get length of that array
    try:
        ba_in = <unsigned char *> ba_temp
    except ValueError:
        raise TypeError("Unable to convert input data to bytearray")

    # Process header
    inlen = len(ba_temp)
    if inlen < 3:
        raise ValueError("Invalid Input: Length of input too short for processing")

    if ba_in[0] != 0x1F or ba_in[1] != 0x9D:
        raise ValueError("Invalid Header Flags Byte: Incorrect magic bytes")

    flags = ba_in[2]
    if flags & 0x60:
        raise ValueError("Invalid Header Flags Byte: Flag byte contains invalid data")

    max_ = flags & 0x1F
    if max_ < 9 or max_ > 16:
        raise ValueError("Invalid Header Flags Byte: Max code size bits out of range")

    if max_ == 9:
        max_ = 10 # 9 doesn't really mean 9

    flags &= 0x80 # true if block compressed

    # Clear table, start at nine bits per symbol
    bits = 9
    mask = 0x1FF
    end = 256 if flags else 255

    # Ensure stream is initially valid
    if inlen == 3:
        return b"" # zero-length input is permitted
    if inlen == 4: # a partial code is not okay
        raise ValueError("Invalid Data: Stream ended in the middle of a code")

    # Allocate memory
    prefix = <unsigned short *> malloc(65536 * sizeof(unsigned short))
    suffix = <unsigned short *> malloc(65536 * sizeof(unsigned short))
    stack = <unsigned int *> malloc(65536 * sizeof(unsigned int))
    if not prefix or not suffix or not stack:
        raise MemoryError("Failed to allocate memory")

    # Try block to ensure memory is freed
    try:
        # Set up: get the first 9-bit code, which is the first decompressed byte,
        # but don't create a table entry until the next code
        buf = ba_in[3] | (ba_in[4] << 8)
        prev = buf & mask 
        buf >>= bits
        left = 16 - bits
        final = prev # code
        if prev > 255:
            raise ValueError("Invalid Data: First code must be a literal")

        # We have output - allocate and set up an output buffer with first byte
        output = bytearray()
        output.append(final)
        output_len += 1

        # Decode codes
        mark = 3 # start of compressed data
        nxt = 5 # consumed five bytes so far

        while nxt < inlen:
            # If the table will be full after this, increment the code size
            if end >= mask and bits < max_:
                # Flush unused input bits and bytes to next 8*bits bit boundary
                # (this is a vestigial aspect of the compressed data format
                # derived from an implementation that made use of a special VAX
                # machine instruction!)
                rem = (nxt - mark) % bits
                if rem:
                    rem = bits - rem
                    if rem >= inlen - nxt:
                        break
                    nxt += rem

                buf = 0
                left = 0

                # mark this new location for computing the next flush
                mark = nxt

                # increment the number of bits per symbol
                bits += 1
                mask = (mask << 1) | 1

            while left < bits:
                if nxt == inlen:
                    raise ValueError("Invalid Data: Stream ended in the middle of a code")
                # Get a code of bits bits
                buf |= ba_in[nxt] << left
                nxt += 1
                left += 8

            code = buf & mask
            buf >>= bits
            left -= bits

            # process clear code (256)
            if code == 256 and flags:
                # Flush unused input bits and bytes to next 8*bits bit boundary
                rem = (nxt - mark) % bits
                if rem:
                    rem = bits - rem
                    if rem > inlen - nxt:
                        break
                    nxt += rem
                buf = 0
                left = 0

                # Mark this location for computing the next flush
                mark = nxt

                # Go back to nine bits per symbol
                bits = 9 # initialize bits and mask
                mask = 0x1FF
                end = 255  # empty table
                continue # get next code

            # Process LZW code
            temp = code  # save the current code
            stack_ptr = 0 # buffer for reversed match

            # Special code to reuse last match
            if code > end:
                # Be picky on the allowed code here, and make sure that the
                # code we drop through (prev) will be a valid index so that
                # random input does not cause an exception
                if code != end + 1 or prev > end:
                    raise ValueError("Invalid Data: Invalid code detected")
                stack[stack_ptr] = final
                stack_ptr += 1
                code = prev

            # Walk through linked list to generate output in reverse order
            while code >= 256:
                stack[stack_ptr] = suffix[code]
                stack_ptr += 1
                code = prefix[code]

            final = code
            stack[stack_ptr] = code
            stack_ptr += 1

            # Link new table entry
            if end < mask:
                end += 1
                prefix[end] = prev
                suffix[end] = final

            # Set previous code for next iteration
            prev = temp

            # Write stack to output in forward order
            for i in range(stack_ptr - 1, -1, -1):
                output.append(stack[i])
                output_len += 1

        # Return the decompressed data as bytes
        return bytes(output)

    # Clean up memory
    finally:
        free(prefix)
        free(suffix)
        free(stack)
