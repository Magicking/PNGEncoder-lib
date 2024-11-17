// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/utils/Base64.sol";

error XoutOfBounds();
error YoutOfBounds();

error InvalidDimensions();

contract PNGImage {
    // PNG signature bytes
    bytes8 constant PNG_SIGNATURE = 0x89504E470D0A1A0A;
    // Chunk type constants
    bytes4 constant IHDR = 0x49484452; // "IHDR" in ASCII
    bytes4 constant IDAT = 0x49444154; // "IDAT" in ASCII  
    bytes4 constant IEND = 0x49454E44; // "IEND" in ASCII
    bytes4 constant PLTE = 0x504C5445; // "PLTE" in ASCII

    struct Image {
        ImageInfo info;
        bytes palette;
        bytes data;
    }

    struct ImageInfo {
        uint32 width;
        uint32 height;
        uint8 bitDepth;
        uint8 colorType;
        uint8 compression;
        uint8 filter;
        uint8 interlace;
    }

    // Create IHDR chunk
    function createIHDR(ImageInfo memory info) internal pure returns (bytes memory) {
        bytes memory chunk = new bytes(13);
        
        // Width
        chunk[0] = bytes1(uint8(info.width >> 24));
        chunk[1] = bytes1(uint8(info.width >> 16));
        chunk[2] = bytes1(uint8(info.width >> 8));
        chunk[3] = bytes1(uint8(info.width));
        
        // Height
        chunk[4] = bytes1(uint8(info.height >> 24));
        chunk[5] = bytes1(uint8(info.height >> 16));
        chunk[6] = bytes1(uint8(info.height >> 8));
        chunk[7] = bytes1(uint8(info.height));
        
        // Other fields
        chunk[8] = bytes1(info.bitDepth);
        chunk[9] = bytes1(info.colorType);
        chunk[10] = bytes1(info.compression);
        chunk[11] = bytes1(info.filter);
        chunk[12] = bytes1(info.interlace);
        
        return assembleChunk(IHDR, chunk);
    }

    // Create chunk with type and data
    function assembleChunk(bytes4 chunkType, bytes memory data) internal pure returns (bytes memory) {
        uint32 length = uint32(data.length);
        bytes memory chunk = new bytes(length + 12); // length(4) + type(4) + data + crc(4)
        
        // Length
        chunk[0] = bytes1(uint8(length >> 24));
        chunk[1] = bytes1(uint8(length >> 16));
        chunk[2] = bytes1(uint8(length >> 8));
        chunk[3] = bytes1(uint8(length));
        
        // Type
        chunk[4] = chunkType[0];
        chunk[5] = chunkType[1];
        chunk[6] = chunkType[2];
        chunk[7] = chunkType[3];
        
        // Data
        for (uint i = 0; i < data.length; i++) {
            chunk[i + 8] = data[i];
        }
        
        // CRC (simplified - should implement proper CRC32)
        uint32 crc = calculateCRC(chunk[4:8], data);
        chunk[length + 8] = bytes1(uint8(crc >> 24));
        chunk[length + 9] = bytes1(uint8(crc >> 16));
        chunk[length + 10] = bytes1(uint8(crc >> 8));
        chunk[length + 11] = bytes1(uint8(crc));
        
        return chunk;
    }

    // Simplified CRC calculation (should implement full CRC32)
    function calculateCRC(bytes memory _type, bytes memory data) internal pure returns (uint32) {
        bytes memory combined = bytes.concat(_type, data);
        uint32 crc = 0;
        for (uint i = 0; i < combined.length; i++) {
            crc = crc + uint8(combined[i]);
        }
        return crc;
    }

    // Create IEND chunk
    function createIEND() internal pure returns (bytes memory) {
        return assembleChunk(IEND, "");
    }

    // Create PLTE chunk
    function createPLTE(bytes memory palette) internal pure returns (bytes memory) {
        return assembleChunk(PLTE, palette);
    }

    // Main encode function
    function encodePNG(Image memory img) public pure returns (string memory) {
        // Assemble PNG
        bytes memory png = new bytes(0);
        png = bytes.concat(png, abi.encodePacked(PNG_SIGNATURE));
        png = bytes.concat(png, createIHDR(img.info));
        png = bytes.concat(png, createPLTE(img.palette));
        png = bytes.concat(png, assembleChunk(IDAT, img.data)); // Should compress pixels
        png = bytes.concat(png, createIEND());

        // Convert to Base64
        return string(Base64.encode(png));
    }

    function newImage(uint32 width, uint32 height) public pure returns (Image memory) {
        if (width == 0 || height == 0) revert InvalidDimensions();

        Image memory image = Image({
            Info: ImageInfo({
            width: width,
            height: height,
            bitDepth: 4,  // 16 bits
            colorType: 3, // Palette
            compression: 0,
            filter: 0,
            interlace: 0
            }),
            palette: new bytes(0),
            data: new bytes(0)
        });
        
        // We used a palette, so we need to store 1 bytes per pixel
        image.data = new bytes(width * height);
        return image;
    }

    function findColorInPalette(bytes memory palette, uint8 r, uint8 g, uint8 b) internal pure returns (int) {
        // For BitDepth == 4
        for (uint i = 0; i < palette.length; i += 3) {
            if (palette[i] == r && palette[i + 1] == g && palette[i + 2] == b) {
                return i / 3;
            }
        }
        return -1;
    }

    function findColorInPaletteOrAdd(Image memory image, uint8 r, uint8 g, uint8 b) internal pure returns (uint8) {
        int colorIdx = findColorInPalette(image.palette, r, g, b);
        uint8 color;    
        if (colorIdx == -1) {
            image.palette = bytes.concat(image.palette, abi.encodePacked(r, g, b));
            color = uint8(image.palette.length / 3 - 1);
        } else {
            color = uint8(colorIdx);
        }
        return color;
    }

    function setPixelAt(Image memory image, uint32 x, uint32 y, uint8 r, uint8 g, uint8 b, uint8 a)
        public
        pure
        returns (Image memory)
    {
        uint32 width = image.infoHeader.width;
        uint32 height = image.infoHeader.height;
        if (!(x < width)) revert XoutOfBounds();
        if (!(y < height)) revert YoutOfBounds();
        uint32 index = x * 4 + ((height - y - 1) * width * 4);
        bytes memory mem = image.data;
        uint8 colorIdx  = findColorInPaletteOrAdd(image, r, g, b);
        assembly {
            index := add(add(mem, 0x20), index)
            mstore8(index, colorIdx)
        }
        return image;
    }

    function B64MimeEncode(string memory mime, bytes memory data) public pure returns (string memory) {
        return string(abi.encodePacked("data:", mime, ";base64,", Base64.encode(data)));
    }

    

}
