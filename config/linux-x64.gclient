solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "custom_deps": {
      "src/third_party/android_deps": None,
      "src/third_party/android_build_tools": None,
      "src/third_party/androidx": None,
      "src/ios": None,
      "src/chromeos": None,
      "src/third_party/fuchsia-sdk": None,
    },
    "custom_vars": {
      "checkout_android": False,
      "checkout_ios": False,
      "checkout_chromeos": False,
      "checkout_fuchsia": False,
      "checkout_nacl": False,
      "checkout_oculus_sdk": False,
    },
  },
]

target_os = ["linux"]
target_os_only = True
