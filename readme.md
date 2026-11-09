XML Notepad is a Windows program that provides a simple intuitive User Interface for browsing and editing XML documents. There are four ways to install it:
1. [ClickOnce® installer](https://lovettsoftwarestorage.blob.core.windows.net/downloads/XmlNotepad/XmlNotepad.application) - this is the most convenient, install it directly from the web browser.
2. [Standalone downloadable installer](https://lovettsoftwarestorage.blob.core.windows.net/downloads/XmlNotepad/XmlNotepadSetup.zip) if you need something that works offline.
Just download the zip file, copy it to the machine you want to install it on, unzip the file on that machine and run `XmlNotepadSetup.msi`.
3. [Windows MSIX installer](https://github.com/microsoft/XmlNotepad/releases) is included in each github
release under the expandable "Assets" heading in case you need a trusted Windows installer.
4. You can also use [WinGet](https://winget.run/pkg/Microsoft/XMLNotepad) as follows: `winget install XmlNotepad` - but this is a bit behind right now due to problems updating the winget repo.

[![image](docs/assets/images/help.png)](https://youtu.be/bmchxiu_oV0)

[XML Notepad](http://microsoft.github.io/XmlNotepad) provides the following useful features:
- XML Schema aware Intellisense
- Find dialog that supports XPath
- Support for XInclude
- Supports XSLT transforms with inline viewer of XSLT output
- Automatic conversion of .csv, .json and .html files
- Handy stats about your XML documents
- XML diff to compare 2 similar XML documents
- Vibrant community with many [updates and bug fixes](http://microsoft.github.io/XmlNotepad/help/updates/).

See [XML Notepad Design](http://microsoft.github.io/XmlNotepad/dev/design/) for information about how this application is built.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Change History

See [Change History](http://microsoft.github.io/XmlNotepad/help/updates/) for a list of new features and bug fixes.

## Help

See [Help Pages](http://microsoft.github.io/XmlNotepad).

## Build an App Attach image (fork)

The [App Attach workflow](.github/workflows/app-attach.yml) builds a signed MSIX bundle from the packaging project, then creates a VHDX image using Microsoft's MSIXMGR. It runs on changes to `src/` on `master`, or manually with **Run workflow** on a selected branch. Enable GitHub Actions on your fork before running it.

Configure these GitHub Actions repository secrets first:

- `MSIX_PFX_BASE64`: Base64-encoded PFX containing your MSIX code-signing certificate and private key (for example, `[Convert]::ToBase64String([IO.File]::ReadAllBytes('signing.pfx'))` in PowerShell). Never commit the PFX.
- `MSIX_PFX_PASSWORD`: Password for that PFX.

The workflow replaces the package manifest's publisher **in the runner only** with the signing certificate's subject, leaving the upstream publisher untouched in Git. The resulting package has a different publisher identity from Microsoft's release. Session hosts must trust the signing certificate and be able to read the VHDX from an SMB share. The workflow uploads the signed `.msixbundle`, `.vhdx`, and SHA-256 checksums as a GitHub Actions artifact retained for 14 days; it does **not** publish the image to a share or register it in Azure Virtual Desktop. Follow the [App Attach setup instructions](https://learn.microsoft.com/en-us/azure/virtual-desktop/app-attach-setup) after validating the image on an equivalent Windows session host. VHDX is used for compatibility across Windows 10 and Windows 11 hosts.