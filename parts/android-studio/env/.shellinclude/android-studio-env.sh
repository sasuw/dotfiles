export PATH="$PATH:/opt/android-studio/bin"

export ANDROID_HOME="$HOME/Android/Sdk"

build_tools_path="$ANDROID_HOME/build-tools/35.0.0."
if [[ -d "${build_tools_path}" ]]; then
	export PATH="$PATH:${build_tools_path}"
fi

cmdline_tools_path="$ANDROID_HOME/cmdline-tools/latest"
if [[ -d "${cmdline_tools_path}" ]]; then
	export PATH="$PATH:${cmdline_tools_path}/bin"
fi

platform_tools_path="$ANDROID_HOME/platform-tools"
if [[ -d "${platform_tools_path}" ]]; then
	export PATH="$PATH:${platform_tools_path}/bin"
fi