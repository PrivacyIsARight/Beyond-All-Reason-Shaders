# Beyond All Reason Shaders

Beyond All Reason Shaders is an extensible framework for dynamically loading and managing custom shaders in Beyond All Reason.

## Usage

Add the widget to `LuaUI/Widgets`. Press **Ctrl+Shift+P** to open the shader selector. Comment blocks are used for parsing some information about the shader, see some of the shaders for an example.

*(Note: Per GLSL specification, the `#version` directive must be the absolute first line, with the header block immediately following).*

## Licensing

Unless otherwise noted, all code and files in this repository are licensed under the GNU General Public License v3.0 (GPLv3).
Files not licensed under the GPLv3 are subject to the terms of the license specified in their respective file headers.
The widget does **NOT** require the specific shaders in this repository, and vice versa.
Because of this, cherry picking specific files can be done, provided you follow the specific files license.

Some of the shaders in `LuaUI/Shaders` carry a **CC BY-NC-SA** license. The **NonCommercial** term means these specific files may not be used in any monetized distribution, regardless of how the rest of this repository is licensed. Per above, if you're planning to do anything commercial, exclude these files.
