// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/utils/Base64.sol";
import "./PNGEncoder.sol";

error XoutOfBounds();
error YoutOfBounds();

contract PNGImage {
    struct InfoHeader {
        uint32 width;
        uint32 height;
        uint32 imageSize;
    }

    struct Image {
        InfoHeader infoHeader;
        bytes data;
    }

    function newImage(uint32 width, uint32 height) public pure returns (Image memory) {
        Image memory image;
        image.infoHeader.width = width;
        image.infoHeader.height = height;
        image.infoHeader.imageSize = width * height * 4;
        image.data = new bytes(width * height * 4);
        return image;
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
        assembly {
            index := add(add(mem, 0x20), index)
            mstore8(index, r)
            index := add(index, 1)
            mstore8(index, g)
            index := add(index, 1)
            mstore8(index, b)
            index := add(index, 1)
            mstore8(index, a)
        }
        return image;
    }

    function encode(Image memory img) public pure returns (bytes memory) {
        return PNGEncoder.encodePNG(
            img.infoHeader.width,
            img.infoHeader.height,
            img.data
        );
    }

    function B64MimeEncode(string memory mime, bytes memory data) public pure returns (string memory) {
        return string(abi.encodePacked("data:", mime, ";base64,", Base64.encode(data)));
    }

}
