# -*- coding: utf-8 -*-"

rebasedb = 'rebase-latest.db'

rebase_baseline_branch = 'chromeos-5.44'

rebase_target = '5.54'

kernel_site = "https://git.kernel.org/"
chromium_site = "https://chromium.googlesource.com/"

# Set to None if unused
android_repo = None
next_repo = None
stable_repo = None
upstream_repo = kernel_site + "pub/scm/bluetooth/bluez"
chromeos_repo = chromium_site + "chromiumos/third_party/bluez"

chromeos_path = "bluez-chrome"
upstream_path = "bluez-upstream"
stable_path = "bluez-stable" if stable_repo else None
android_path = "bluez-android" if android_repo else None
next_path = "bluez-next" if next_repo else None

# Clear subject_droplist as follows to keep andoid patches
# subject_droplist = []
subject_droplist = []

droplist = []

topiclist = \
    [["bluetoothd", ["src"]],
    ["btmon", ["monitor"]]
    ]
