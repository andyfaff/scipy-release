#!/usr/bin/env python
"""
check_msvc_runtime.py [MODULE]

Check that a Windows wheel vendors the MSVC C++ runtime.

The extension modules are built against the MSVC C++ standard library. Unlike
vcruntime140.dll, msvcp140.dll is not part of Windows and is not shipped with
CPython, so delvewheel vendors it into ``scipy.libs`` under a mangled name.
When that silently stops happening, importing SciPy can fail with "DLL load
failed" on machines without the VC++ redistributable installed - see
scipy/scipy#14998 and scipy/scipy#17191.

This is a no-op on non-Windows platforms.

"""

import pathlib
import sys
import argparse
import subprocess


def main():
    p = argparse.ArgumentParser(usage=__doc__.rstrip())
    p.add_argument("module", nargs="?", default="scipy")
    args = p.parse_args()

    if sys.platform != "win32":
        sys.exit(0)

    # Drop '' from sys.path
    sys.path.pop(0)

    # Find module path
    __import__(args.module)
    mod = sys.modules[args.module]

    # The vendored DLLs are installed alongside the package, in <module>.libs
    libs_path = pathlib.Path(mod.__file__).parent.parent / f"{args.module}.libs"

    vendored = sorted(p.name for p in libs_path.glob("msvcp140*.dll"))
    if not vendored:
        print(
            f"ERROR: no msvcp140*.dll found in {libs_path}. The MSVC C++ "
            "runtime is not being vendored, so importing this wheel may fail "
            "on machines without the VC++ redistributable installed.\n"
        )
        sys.exit(1)

    print(f"Found vendored MSVC C++ runtime: {vendored}")

    # now check that the runtime is still correctly signed
    print("The msvcp path is", libs_path / vendored[0])

    verified = verify_microsoft_signature(libs_path / vendored[0])
    if not verified:
        print("The bundled msvcp140 DLL does not have a valid signature.")
        sys.exit(1)

    print("The signature of the vendored MSVC C++ runtime has been verified")

    sys.exit(0)


def verify_microsoft_signature(file_path):
    # This fetches the signature status and the Subject name of the signer
    ps_command = (
        f' $sig = Get-AuthenticodeSignature "{file_path}"; '
        f'Write-Output "$($sig.Status)|$($sig.SignerCertificate.Subject)" '
    )

    try:
        result = subprocess.run(
            ["powershell", "-Command", ps_command],
            capture_output=True,
            text=True,
            check=True,
        )

        # Parse output (format will be: Status|Subject)
        output = result.stdout.strip()
        if not output or "|" not in output:
            print("Error: Could not retrieve file signature info.")
            return False

        status, subject = output.split("|", 1)

        # Check if the cryptographic signature is structurally intact
        if status != "Valid":
            print(
                f"Warning: File signature status is '{status}'. The file has been modified."
            )
            return False

        # Check if the signer identity is actually Microsoft
        if "Microsoft Corporation" in subject or "CN=Microsoft" in subject:
            print("Success: File is unmodified and authentically signed by Microsoft!")
            return True
        else:
            print(
                f"Warning: Valid signature found, but it belongs to someone else: {subject}"
            )
            return False

    except subprocess.CalledProcessError as e:
        print(f"Error executing verification check: {e}")
        return False


if __name__ == "__main__":
    main()
