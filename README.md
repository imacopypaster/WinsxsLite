# WinsxsLite
WinsxsLite tool for cleaning winsxs folder in Windows 7

WinsxsLite can work on offline system images.
WinsxsLite v1.86 and later can work on images that are not in the root of a drive.

If the image is packed in a .wim file, one has to extract, process, and recapture the image.
Mounting does NOT work.
Here's an example:

Open a command prompt.

md D:\tempimage

imagex /INFO F:\sources\install.wim
imagex /APPLY F:\sources\install.wim 1 D:\tempimage

// Now, edit WinsxsLite's config.txt so it knows where to look:
// :ROOT=D:\tempimage

// Run WinsxsLite.
// When done:

imagex /COMPRESS maximum /CAPTURE D:\tempimage D:\install.wim "image name" "image description"
imagex /INFO D:\install.wim

// All done.


Imagex.exe is part of the Windows Automated Installation Kit (WAIK).

What's needed are 3 files:
imagex.exe
wimfltr.inf
wimfltr.sys

To install the .sys file, right-click the .inf, and chose 'Install'.
