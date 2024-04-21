// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./digits/FiguresDoubleDigitsLib.sol";
import "./FiguresUtilLib.sol";

library FiguresDoubles {
    function chooseStringsDoubles(
        uint8 number,
        uint8 index1,
        uint8 index2
    ) public pure returns (bool[][2] memory b) {
        FiguresUtilLib.FigStrings memory strings = getFigStringsDoubles(number);
        return
            FiguresUtilLib._chooseStringsDouble(
                number,
                strings.s1,
                strings.s2,
                index1,
                index2
            );
    }

    function getFigStringsDoubles(uint8 number)
        private
        pure
        returns (FiguresUtilLib.FigStrings memory)
    {
        FiguresUtilLib.FigStrings memory figStrings;

        do {
            if (number == 0) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS0S1,
                    8
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS0S2,
                    8
                );
                break;
            }
            if (number == 1) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS1S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS1S2,
                    24
                );
                break;
            }
            if (number == 2) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS2S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS2S2,
                    24
                );
                break;
            }
            if (number == 3) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS3S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS3S2,
                    24
                );
                break;
            }
            if (number == 4) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS4S1,
                    9
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS4S2,
                    16
                );
                break;
            }
            if (number == 5) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS5S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS5S2,
                    24
                );
                break;
            }
            if (number == 6) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS6S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS6S2,
                    33
                );
                break;
            }
            if (number == 7) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS7S1,
                    13
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS7S2,
                    4
                );
                break;
            }
            if (number == 8) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS8S1,
                    36
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS8S2,
                    36
                );
                break;
            }
            if (number == 9) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS9S1,
                    36
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS9S2,
                    24
                );
                break;
            }
        } while (false);

        return figStrings;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library FiguresUtilLib {
    struct FigStrings {
        string[] s1;
        string[] s2;
    }

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _assignValuesSingle(string memory input, uint16 size)
        internal
        pure
        returns (string[] memory)
    {
        return _assignValues(input, size, 50);
    }

    function _assignValuesDouble(string memory input, uint16 size)
        internal
        pure
        returns (string[] memory)
    {
        return _assignValues(input, size, 25);
    }

    function _assignValues(
        string memory input,
        uint16 size,
        uint8 length
    ) internal pure returns (string[] memory) {
        string[] memory output = new string[](size);
        for (uint256 i = 0; i < size; i++) {
            output[i] = substring(input, i * length, i * length + length);
        }
        return output;
    }

    function _chooseStringsSingle(
        uint8 number,
        string[] memory strings1,
        string[] memory strings2,
        uint8 index1,
        uint8 index2
    ) internal pure returns (bool[][2] memory b) {
        return _chooseStrings(number, strings1, strings2, index1, index2, 50);
    }

    function _chooseStringsDouble(
        uint8 number,
        string[] memory strings1,
        string[] memory strings2,
        uint8 index1,
        uint8 index2
    ) internal pure returns (bool[][2] memory b) {
        return _chooseStrings(number, strings1, strings2, index1, index2, 25);
    }

    function _chooseStrings(
        uint8 number,
        string[] memory strings1,
        string[] memory strings2,
        uint8 index1,
        uint8 index2,
        uint8 length
    ) private pure returns (bool[][2] memory b) {
        string[2] memory s;
        // some arrays are shorter than the random number generated
        uint256 availableIndex1 = index1 % strings1.length;
        uint256 availableIndex2 = index2 % strings2.length;
        s[0] = strings1[availableIndex1];
        s[1] = strings2[availableIndex2];

        // Special cases for 0, 1, 7
        if (number == 0 || number == 1 || number == 7) {
            if (length == 25) {
                while (
                    keccak256(bytes(substring(s[0], 20, 24))) !=
                    keccak256(bytes(substring(s[1], 0, 4)))
                ) {
                    uint256 is2 = ((availableIndex2 + availableIndex1++) %
                        strings2.length);
                    s[1] = strings2[is2];
                }
            }
            if (length == 50) {
                while (
                    keccak256(bytes(substring(s[0], 40, 49))) !=
                    keccak256(bytes(substring(s[1], 0, 9)))
                ) {
                    uint256 is2 = ((availableIndex2 + availableIndex1++) %
                        strings2.length);
                    s[1] = strings2[is2];
                }
            }
        }

        b[0] = _returnBoolArray(s[0]);
        b[1] = _returnBoolArray(s[1]);

        return b;
    }

    function checkString(string memory s1, string memory s2) private pure {}

    function _returnBoolArray(string memory s)
        internal
        pure
        returns (bool[] memory)
    {
        bytes memory b = bytes(s);
        bool[] memory a = new bool[](b.length);
        for (uint256 i = 0; i < b.length; i++) {
            uint8 z = (uint8(b[i]));
            if (z == 48) {
                a[i] = true;
            } else if (z == 49) {
                a[i] = false;
            }
        }
        return a;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library FiguresDoubleDigitsLib {
    string public constant FS0S1 =
        "00000011100111001110011100000000000011100111001110000000000000000011100111000000000000000000000011100000000100001000010000100000000000000100001000010000000000000000000100001000000000000000000000000100";
    string public constant FS0S2 =
        "01110011100111001110000000111001110011100000000000011100111000000000000000001110000000000000000000000010000100001000010000000001000010000100000000000000100001000000000000000000010000000000000000000000";

    string public constant FS1S1 =
        "000011000110001100011000100001000011000110001100010000100001000011000110001000010000100001000011000100001110011100111001110010000100001110011100111001000010000100001110011100100001000010000100001110010000111101111011110111101000010000111101111011110100001000010000111101111010000100001000010000111101000111101111011110111101100011000111101111011110110001100011000111101111011000110001100011000111101100111101111011110111101110011100111101111011110111001110011100111101111011100111001110011100111101110001110011100111001110011000110001110011100111001100011000110001110011100110001100011000110001110011";

    string public constant FS1S2 =
        "100011000110001100010000010001100011000100000000001000110001000000000000000100010000000000000000000011001110011100111001000001100111001110010000000000110011100100000000000000011001000000000000000000001110111101111011110100000111011110111101000000000011101111010000000000000001110100000000000000000000110111101111011110110000011011110111101100000000001101111011000000000000000110110000000000000000000010111101111011110111000001011110111101110000000000101111011100000000000000010111000000000000000000001001110011100111001100000100111001110011000000000010011100110000000000000001001100000000000000000000";

    string public constant FS2S1 =
        "000001111011110111100000000000111001110011100000000000011000110001100000000000001000010000100000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000";

    string public constant FS2S2 =
        "000000111101111011110000000000001110011100111000000000000011000110001100000000000000100001000010000000000011110111100000000000000000111001110000000000000000001100011000000000000000000010000100000000000000000000011110111100000000000000000111001110000000000000000001100011000000000000000000010000100000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000";

    string public constant FS3S1 = FS2S1;

    string public constant FS3S2 = FS2S1;

    string public constant FS4S1 =
        "011010110101101011010000001101011010110100000000000110101101000000000000000001010010100101001010000000101001010010100000000000010100101000000000000000010010100101001010010000001001010010100100000000000100101001000000000000000";

    string public constant FS4S2 =
        "0000011101111011110111101000001101111011110111101100000110011100111001110010000010001100011000110001000000000011101111011110100000000001101111011110110000000000110011100111001000000000010001100011000100000000000000011101111010000000000000001101111011000000000000000110011100100000000000000010001100010000000000000000000011101000000000000000000001101100000000000000000000110010000000000000000000010001";

    string public constant FS5S1 = FS2S2;

    string public constant FS5S2 = FS3S2;

    string public constant FS6S1 = FS2S2;

    string public constant FS6S2 =
        "000000111001110011100000000000000000111001110000000000001110011100000000000000000000000000011100000000000000000111000000000000000001110000000000000000000000100001000010000000000000001000010000100000000000000010000100001000000000000100001000000000000000000001000010000000000000000000010000100000000000000000000001000010000000000000000000010000100000000000000000000100001000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000001000000000000000000000000010000000000000000000000000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000000000110000000000000000000000000000110000000000000000000000000000110000000000000110001100000000000000000000000110001100000000000000110001100000000000000000000000110001100000000000011000110001100000000000000110001100011000000";

    string public constant FS7S1 =
        "0000011110111101111011110000000000011110111101111000000000000000011110111100000000000000000000011110000000000000000000000000000000111001110011100111000000000000111001110011100000000000000000111001110000000000000000000000111000000011000110001100011000000000000011000110001100000000000000000011000110000000000000000000000011000";

    string public constant FS7S2 =
        "1111011110111101111011110111001110011100111001110011000110001100011000110001000010000100001000010000";

    string public constant FS8S1 =
        "000000111001110011100000000000000000111001110000000000001110011100000000000000000110001100011000000000000001100011000110000000000000000000000111000000000000000001110000000000000000011100000000000000000000001000010000100000000000000010000100001000000000000000100001000010000000000001100000000000000000000000000001100000000000000000000000000001100000000000000110000000000000000000000000000110000000000000000000000000000110000000000000000010000100000000000000000000100001000000000000000000001000010000000000001000010000000000000000000010000100000000000000000000100001000000000000000001100011000000000000000000000001100011000000000000001100011000000000000000000000001100011000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000001000000000000000000000000010000000000000000000000000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000";

    string public constant FS8S2 = FS8S1;

    string public constant FS9S1 =
        "000000111001110011100000000000011100111000000000000000000000011100111000000000000111000000000000000000000000000111000000000000000000000000000111000000000000100001000010000000000000001000010000100000000000000010000100001000000000000000001000010000000000000000000010000100000000000000000000100001000000000000100001000000000000000000001000010000000000000000000010000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000000000000001000000000000000000000000010000000000000000000000000100000000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000000000011000000000000000000110000000000000000001100000000000000000000000000000000001100000000000000000011000000000000000000110000000000000000000000000001100011000000000000011000110000000000000000000000001100011000000000000011000110000000000000000011000110001100000000000000110001100011000000";

    string public constant FS9S2 = FS2S1;
}