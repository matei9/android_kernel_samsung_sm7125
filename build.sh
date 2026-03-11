#!/bin/bash
#
# Build script for FloppyKernel (ginkgo).
# Based on build script for Quicksilver, by Ghostrider.
# Copyright (C) 2020-2021 Adithya R. (original version)
# Copyright (C) 2022-2025 Flopster101 (rewrite)
# Copyright (C) 2025-2026 notfleshka (modifications)

# Main Variables
KERNEL_NAME="crDroid"    # Kernel's name
KERNEL_VER="4.14.356"     # Kernel's version
BUILD_HOST="testamic-buildserver"     # Build host name
EXTRA_NOTES="rksu"    # Extra notes to add to the zip name
EXTRA_CONFIGS=()  # Extra config files to apply
OUT_IMAGE="out/arch/arm64/boot/Image.gz"  # Kernel image path
# EXTRA_CONFIGS+=("vendor/blablabla.config") # Example
OUT_DTBO="out/arch/arm64/boot/dts/qcom/atoll-ab-idp.dtb" # DTBO path
USE_CCACHE=1  # Use ccache? 1 - yes, 0 - no
DO_CLEANUP=1 # Cleanup after build? 1 - yes, 0 - no
DO_CLEAN=1 # Clean build? 1 - yes, 0 - no
DO_MENUCONFIG=0 # Use Menuconfig? 1 - yes, 0 - no
DO_REGEN=0 # Regenerate defconfig? 1 - yes, 0 - no
DO_FLTO=0 # Full LTO? 1 - yes, 0 - no
DO_A52Q=0 # Use Galaxy A52 defconfig? 1 - yes, 0 - no
DO_A72Q=0 # Use Galaxy A72 defconfig? 1 - yes, 0 - no
DO_KSU_DRIVER=1 # Shall script git clone a kernelsu driver? 1 - yes, 0 - no
KSU_REPO="https://github.com/rsuntk/KernelSU" # KernelSU repository URL, default: RKSU
KSU_BRANCH="main" # KernelSU branch to clone, default: main
LOG_UPLOAD=0 # Upload log to bashupload.com? 1 - yes, 0 - no
# LINKER="ld.lld" # Linker to use
CLANG_TYPE="rm69" # Toolchain type: aosp, sdclang, proton, rm69, lolz, greenforce, zyc, rv, custom
# AnyKernel3
AK3_URL="https://github.com/notfleshka/AnyKernel3-A52-A72"
AK3_BRANCH="master"
AK3_DIR="$WP/AnyKernel3"
# Local
LOCAL=1 # Local build? 1 - yes, 0 - no
if [[ "$LOCAL" == "1" ]]; then
        echo "INFO: Local build enabled"
        WP="$(pwd)"
else
        echo "INFO: Local build disabled, handled by your environment"
fi

## Variables
# Toolchains
AOSP_REPO="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/master"
AOSP_ARCHIVE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master"
SD_REPO="https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang"
SD_BRANCH="14"
PC_REPO="https://github.com/kdrag0n/proton-clang"
LZ_REPO="https://gitlab.com/Jprimero15/lolz_clang.git"
RC_URL="https://github.com/kutemeikito/RastaMod69-Clang/releases/download/RastaMod69-Clang-20.0.0-release/RastaMod69-Clang-20.0.0.tar.gz"
GC_REPO="https://api.github.com/repos/greenforce-project/greenforce_clang/releases/latest"
ZC_REPO="https://raw.githubusercontent.com/ZyCromerZ/Clang/refs/heads/main/Clang-main-link.txt"
RV_REPO="https://api.github.com/repos/Rv-Project/RvClang/releases/latest"
GCC_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"
GCC64_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9"

# Custom toolchain directory
if [[ -z "$CUST_DIR" ]]; then
    CUST_DIR="$WP/custom-toolchain"
else
    echo -e "\nINFO: Overriding custom toolchain path..."
fi

# Workspace
if [[ -d /workspace ]]; then
    WP="/workspace"
    IS_GP=1
else
    IS_GP=0
fi

if [[ -z "$WP" ]]; then
    echo -e "\nERROR: Environment not Gitpod! Please set the WP env var...\n"
    exit 1
fi

if [[ ! -d drivers ]]; then
    echo -e "\nERROR: Please execute from top-level kernel tree\n"
    exit 1
fi

if [[ "$IS_GP" == "1" ]]; then
    export KBUILD_BUILD_USER="$BUILD_HOST"
    export KBUILD_BUILD_HOST="$BUILD_HOST"
fi

# Other
# KERNEL_URL=""
SECONDS=0 # builtin bash timer
DATE="$(date '+%Y%m%d-%H%M')"
# Paths
SD_DIR="$WP/sdclang"
AC_DIR="$WP/aospclang"
PC_DIR="$WP/protonclang"
RC_DIR="$WP/rm69clang"
LZ_DIR="$WP/lolzclang"
GCC_DIR="$WP/gcc"
GCC64_DIR="$WP/gcc64"
GC_DIR="$WP/greenforceclang"
ZC_DIR="$WP/zycclang"
RV_DIR="$WP/rvclang"
KDIR="$(readlink -f .)"
USE_GCC_BINUTILS="0"


for arg in "$@"; do
    if [[ "$arg" == *m* ]]; then
        echo "INFO: Menuconfig enabled"
        DO_MENUCONFIG=1
    fi
    if [[ "$arg" == *c* ]]; then
        echo "INFO: Clean build enabled"
        DO_CLEAN=1
    fi
    if [[ "$arg" == *r* ]]; then
        echo "INFO: Config regeneration mode"
        DO_REGEN=1
    fi
    if [[ "$arg" == *l* ]]; then
        echo "INFO: Full-LTO enabled"
        echo "WARNING: Full-LTO is VERY resource heavy and may take a long time to compile!"
        DO_FLTO=1
    fi
    if [[ "$arg" == *a72* ]]; then
        echo "INFO: Galaxy A72 build"
        DO_A72Q=1
    fi
    if [[ "$arg" == *a52* ]]; then
        echo "INFO: Galaxy A52 build"
        DO_A52Q=1
    fi
done

if [[ "$DO_A52Q" -eq 1 && "$DO_A72Q" -eq 1 ]]; then
    echo "ERROR: Please select only one device (A52 or A72)"
    exit 1
fi
if [ $DO_A72Q -eq 1 ]; then
    CODENAME="a72q"
    DEFAULT_DEFCONFIG="vendor/lineage-a72q_defconfig"
    DEVICE="Galaxy A72"
elif [ $DO_A52Q -eq 1 ]; then
    CODENAME="a52q"
    DEFAULT_DEFCONFIG="vendor/lineage-a52q_defconfig"
    DEVICE="Galaxy A52"
fi

DEFCONFIG="$DEFAULT_DEFCONFIG"


## Build type
LINUX_VER=$(make kernelversion 2>/dev/null)

ZIP_PATH="$WP/$KERNEL_NAME-$CODENAME-$KERNEL_VER-$EXTRA_NOTES-$DATE.zip"

echo -e "\nINFO: Build info:
- Device: $DEVICE ($CODENAME)
- Kernel Name: $KERNEL_NAME
- Kernel Version: $KERNEL_VER
- Notes: $EXTRA_NOTES
- Extra configs: ${EXTRA_CONFIGS[*]:-None}
- Linux version: $LINUX_VER
- Defconfig: $DEFCONFIG
- Build date: $DATE
- Clang type: $CLANG_TYPE
- Clean build: $([ "$DO_CLEAN" -eq 1 ] && echo "Yes" || echo "No")
"

install_deps_deb() {
    # Dependencies
    UB_DEPLIST="make(4.3) lz4 brotli flex bc cpio kmod ccache zip libtinfo5 python3 libssl-dev"
        echo "INFO: Make sure you have these dependencies installed before proceeding: $UB_DEPLIST"
        echo "INFO: Names of these dependencies are for Ubuntu/Debian-based distros, please check how are they called on other distros."
        read -p "Are these dependencies installed? (y/n): " confirm
        case "${confirm,,}" in
            y|yes)
                echo "INFO: Continuing..."
                ;;
            *)
                echo "ERROR: Please install the dependencies manually before proceeding."
                exit 1
                ;;
        esac
}

get_toolchain() {
    local toolchain_type="$1"
    local toolchain_dir=""

    case "$toolchain_type" in
        aosp)
            toolchain_dir="$AC_DIR"
            USE_GCC_BINUTILS=1
            if [[ ! -d "$toolchain_dir" ]]; then
                echo -e "\nINFO: AOSP Clang not found! Cloning to $toolchain_dir..."
                CURRENT_CLANG=$(curl -s "$AOSP_REPO" | grep -oE "clang-r[0-9a-f]+" | sort -u | tail -n1)
                if ! curl -LSsO "$AOSP_ARCHIVE/$CURRENT_CLANG.tar.gz"; then
                    echo -e "\nERROR: Cloning failed! Aborting..."
                    exit 1
                fi
                mkdir -p "$toolchain_dir" && tar -xf ./*.tar.gz -C "$toolchain_dir" && rm ./*.tar.gz
                touch "$toolchain_dir/bin/aarch64-linux-gnu-elfedit" && chmod +x "$toolchain_dir/bin/aarch64-linux-gnu-elfedit"
                touch "$toolchain_dir/bin/arm-linux-gnueabi-elfedit" && chmod +x "$toolchain_dir/bin/arm-linux-gnueabi-elfedit"
            fi
            ;;
        sdclang)
            toolchain_dir="$SD_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: SD Clang not found! Cloning to $toolchain_dir..."
                if ! git clone -q -b "$SD_BRANCH" --depth=1 "$SD_REPO" "$toolchain_dir"; then
                    echo "ERROR: Cloning failed! Aborting..."
                    exit 1
                fi
            fi
            ;;
        proton)
            toolchain_dir="$PC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: Proton Clang not found! Cloning to $toolchain_dir..."
                if ! git clone -q --depth=1 "$PC_REPO" "$toolchain_dir"; then
                    echo "ERROR: Cloning failed! Aborting..."
                    exit 1
                fi
            fi
            ;;
        rm69)
            toolchain_dir="$RC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: RastaMod69 Clang not found! Cloning to $toolchain_dir..."
                wget -q --show-progress "$RC_URL" -O "$WP/RastaMod69-clang.tar.gz"
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: Download failed! Aborting..."
                    rm -f "$WP/RastaMod69-clang.tar.gz"
                    exit 1
                fi
                rm -rf clang && mkdir -p "$toolchain_dir" && tar -xf "$WP/RastaMod69-clang.tar.gz" -C "$toolchain_dir"
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: Extraction failed! Aborting..."
                    rm -f "$WP/RastaMod69-clang.tar.gz"
                    exit 1
                fi
                rm -f "$WP/RastaMod69-clang.tar.gz"
                echo "INFO: RastaMod69 Clang successfully cloned to $toolchain_dir"
            fi
            ;;
        lolz)
            toolchain_dir="$LZ_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: Lolz Clang not found! Cloning to $toolchain_dir..."
                if ! git clone -q --depth=1 "$LZ_REPO" "$toolchain_dir"; then
                    echo "ERROR: Cloning failed! Aborting..."
                    exit 1
                fi
            fi
            ;;
        greenforce)
            USE_GCC_BINUTILS=1
            toolchain_dir="$GC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo -e "\nINFO: Greenforce Clang not found! Cloning to $toolchain_dir..."
                LATEST_RELEASE=$(curl -s $GC_REPO | grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f 4)
                if [[ -z "$LATEST_RELEASE" ]]; then
                    echo "ERROR: Failed to fetch the latest Greenforce Clang release! Aborting..."
                    exit 1
                fi
                if ! wget -q --show-progress -O "$WP/greenforce-clang.tar.gz" "$LATEST_RELEASE"; then
                    echo "ERROR: Download failed! Aborting..."
                    exit 1
                fi
                mkdir -p "$toolchain_dir"
                tar -xf "$WP/greenforce-clang.tar.gz" -C "$toolchain_dir"
                rm "$WP/greenforce-clang.tar.gz"
            fi
            ;;
        custom)
            toolchain_dir="$CUST_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo -e "\nERROR: Custom toolchain not found! Aborting..."
                echo -e "INFO: Please provide a toolchain at $CUST_DIR or select a different toolchain"
                exit 1
            fi
            ;;
        zyc)
            toolchain_dir="$ZC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
            echo -e "\nINFO: ZyC Clang not found! Cloning to $toolchain_dir..."
            fi

            # Check and cache the latest version
            ZYC_VERSION_FILE="$WP/zyc-clang-version.txt"
            LATEST_VERSION=$(curl -s "$ZC_REPO" | head -n 1)
            if [[ -z "$LATEST_VERSION" ]]; then
                echo "INFO: Failed to check ZyC Clang version"
            else
                if [[ -f "$ZYC_VERSION_FILE" ]]; then
                    CURRENT_VERSION=$(cat "$ZYC_VERSION_FILE")
                    if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
                        echo "INFO: A new version of ZyC Clang is available: $LATEST_VERSION"
                        echo "$LATEST_VERSION" > "$ZYC_VERSION_FILE"
                    fi
                else
                    echo "$LATEST_VERSION" > "$ZYC_VERSION_FILE"
                fi
            fi

            if [[ ! -d "$toolchain_dir" ]]; then
                if [[ -f "$ZYC_VERSION_FILE" ]]; then
                    echo "$LATEST_VERSION" > "$ZYC_VERSION_FILE"
                fi
                if [[ -z "$LATEST_VERSION" ]]; then
                    echo "ERROR: Failed to fetch the latest ZyC Clang release! Aborting..."
                    exit 1
                fi
                if ! wget -q --show-progress -O "$WP/zyc-clang.tar.gz" "$LATEST_VERSION"; then
                    echo "ERROR: Download failed! Aborting..."
                    rm -f "$ZYC_VERSION_FILE"
                    exit 1
                fi
                mkdir -p "$toolchain_dir"
                if ! tar -xf "$WP/zyc-clang.tar.gz" -C "$toolchain_dir"; then
                    echo "ERROR: Extraction failed! Aborting..."
                    rm -f "$WP/zyc-clang.tar.gz" "$ZYC_VERSION_FILE"
                    exit 1
                fi
                rm "$WP/zyc-clang.tar.gz"
            fi
            ;;
        rv)
            toolchain_dir="$RV_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
            echo -e "\nINFO: RvClang not found! Fetching the latest version..."
            LATEST_RELEASE=$(curl -s "$RV_REPO" | grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f 4)
            if [[ -z "$LATEST_RELEASE" ]]; then
                echo "ERROR: Failed to fetch the latest RvClang release! Aborting..."
                exit 1
            fi
            if ! wget -q --show-progress -O "$WP/rvclang.tar.gz" "$LATEST_RELEASE"; then
                echo "ERROR: Download failed! Aborting..."
                exit 1
            fi
            mkdir -p "$toolchain_dir"
            if ! tar -xf "$WP/rvclang.tar.gz" -C "$toolchain_dir"; then
                echo "ERROR: Extraction failed! Aborting..."
                rm -f "$WP/rvclang.tar.gz"
                exit 1
            fi
            rm "$WP/rvclang.tar.gz"
            # Move contents of the inner "RvClang" folder to $RV_DIR
            if [[ -d "$toolchain_dir/RvClang" ]]; then
                mv "$toolchain_dir/RvClang"/* "$toolchain_dir/"
                rmdir "$toolchain_dir/RvClang"
            fi
            fi
            ;;
        *)
            echo -e "\nERROR: Unknown toolchain type: $toolchain_type"
            exit 1
            ;;
    esac

    if [[ "$USE_GCC_BINUTILS" == "1" ]]; then
        if [[ ! -d "$GCC_DIR" ]]; then
            echo "INFO: GCC not found! Cloning to $GCC_DIR..."
            if ! git clone -q -b lineage-19.1 --depth=1 "$GCC_REPO" "$GCC_DIR"; then
                echo "ERROR: Cloning failed! Aborting..."
                exit 1
            fi
        fi
        if [[ ! -d "$GCC64_DIR" ]]; then
            echo "INFO: GCC64 not found! Cloning to $GCC64_DIR..."
            if ! git clone -q -b lineage-19.1 --depth=1 "$GCC64_REPO" "$GCC64_DIR"; then
                echo "ERROR: Cloning failed! Aborting..."
                exit 1
            fi
        fi
    fi
}

prep_toolchain() {
    local toolchain_type="$1"
    local toolchain_dir=""

    case "$toolchain_type" in
        aosp)
            toolchain_dir="$AC_DIR"
            echo "INFO: Toolchain: AOSP Clang"
            ;;
        sdclang)
            toolchain_dir="$SD_DIR/compiler"
            echo "INFO: Toolchain: Snapdragon Clang"
            ;;
        proton)
            toolchain_dir="$PC_DIR"
            echo "INFO: Toolchain: Proton Clang"
            ;;
        rm69)
            toolchain_dir="$RC_DIR"
            echo "INFO: Toolchain: RastaMod69 Clang"
            ;;
        lolz)
            toolchain_dir="$LZ_DIR"
            echo "INFO: Toolchain: Lolz Clang"
            ;;
        greenforce)
            toolchain_dir="$GC_DIR"
            echo "INFO: Toolchain: Greenforce Clang"
            ;;
        zyc)
            toolchain_dir="$ZC_DIR"
            echo "INFO: Toolchain: ZyC Clang"
            ;;
        custom)
            toolchain_dir="$CUST_DIR"
            echo "INFO: Toolchain: Custom toolchain"
            ;;
        rv)
            toolchain_dir="$RV_DIR"
            echo "INFO: Toolchain: RvClang"
            ;;
        *)
            echo -e "\nERROR: Unknown toolchain type: $toolchain_type"
            exit 1
            ;;
    esac

    export PATH="${toolchain_dir}/bin:${PATH}"
    if [[ "$USE_GCC_BINUTILS" == "1" ]]; then
        export PATH="${GCC64_DIR}/bin:${GCC_DIR}/bin:${PATH}"
    fi
    KBUILD_COMPILER_STRING=$("$toolchain_dir/bin/clang" -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING

    if [[ "$USE_GCC_BINUTILS" == "1" ]]; then
        CCARM64_PREFIX="aarch64-linux-androideabi-"
        CCARM_PREFIX="arm-linux-androideabi-"
    else
        CCARM64_PREFIX="aarch64-linux-gnu-"
        CCARM_PREFIX="arm-linux-gnueabi-"
    fi
}

## Pre-build dependencies
install_deps_deb
get_toolchain "$CLANG_TYPE"
prep_toolchain "$CLANG_TYPE"


prep_build() {
    # Prepare ccache
    if [[ "$USE_CCACHE" == "1" ]]; then
        echo "INFO: ccache enabled"
        if [[ "$IS_GP" == "1" ]]; then
            export CCACHE_DIR="$WP/.ccache"
            ccache -M 10G
        else
            echo "WARNING: Environment is not Gitpod, please make sure you setup your own ccache configuration!"
        fi
    fi

    # Show compiler information
    echo -e "INFO: Compiler: $KBUILD_COMPILER_STRING\n"
}
    # Prepare KernelSU if needed
    if [[ "$DO_KSU_DRIVER" == "1" ]]; then
        echo "INFO: KernelSU: cloning driver to $WP/KernelSU..."
        git clone $KSU_REPO -b "$KSU_BRANCH" "$WP/KernelSU"
        echo "INFO: KernelSU: modifying Makefile..."
        grep -q "kernelsu" "drivers/Makefile" || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "drivers/Makefile" 
        echo "INFO: KernelSU: modifying Kconfig..."
        grep -q "source \"drivers/kernelsu/Kconfig\"" "drivers/Kconfig" || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" "drivers/Kconfig" 
        echo "INFO: KernelSU: done adding driver, make sure to add KSU hooks and enable CONFIG_KSU!"
    else
        echo "INFO: KernelSU driver not requested, skipping..."
    fi

build() {
    export LLVM=1 LLVM_IAS=1
    export ARCH=arm64
    mkdir -p out

    make O=out ARCH=arm64 "$DEFCONFIG" ${EXTRA_CONFIGS[*]} 2>&1 | tee log.txt

    # Delete leftovers
    if [[ "$DO_CLEANUP" == "1" ]]; then
        echo -e "INFO: Deleting leftovers"
        rm -f out/arch/arm64/boot/Image*
        rm -f out/arch/arm64/boot/dtbo*
        rm -f log.txt
    fi


    if [[ "$DO_MENUCONFIG" == "1" ]]; then
        make O=out menuconfig
    fi

    if [[ "$DO_REGEN" == "1" ]]; then
        cp -f out/.config "arch/arm64/configs/$DEFCONFIG"
        echo "INFO: Configuration regenerated. Check the changes!"
        exit 0
    fi

    if [[ "$DO_FLTO" == "1" ]]; then
        scripts/config --file "$KDIR/out/.config" --enable CONFIG_LTO_CLANG
        scripts/config --file "$KDIR/out/.config" --disable CONFIG_THINLTO
    fi

    ## Start the build
    echo -e "\nINFO: Starting compilation...\n"

    if [[ "$USE_CCACHE" == "1" ]]; then
        make -j$(nproc --all) O=out \
        CC="ccache clang" \
        CROSS_COMPILE="$CCARM64_PREFIX" \
        CROSS_COMPILE_ARM32="$CCARM_PREFIX" \
        CLANG_TRIPLE="aarch64-linux-gnu-" \
        READELF="llvm-readelf" \
        OBJSIZE="llvm-size" \
        OBJDUMP="llvm-objdump" \
        OBJCOPY="llvm-objcopy" \
        STRIP="llvm-strip" \
        NM="llvm-nm" \
        AR="llvm-ar" \
        HOSTAR="llvm-ar" \
        HOSTAS="llvm-as" \
        HOSTNM="llvm-nm" \
        LD="ld.lld" 2>&1 | tee log.txt
    else
        make -j$(nproc --all) O=out \
        CC="clang" \
        CROSS_COMPILE="$CCARM64_PREFIX" \
        CROSS_COMPILE_ARM32="$CCARM_PREFIX" \
        CLANG_TRIPLE="aarch64-linux-gnu-" \
        READELF="llvm-readelf" \
        OBJSIZE="llvm-size" \
        OBJDUMP="llvm-objdump" \
        OBJCOPY="llvm-objcopy" \
        STRIP="llvm-strip" \
        NM="llvm-nm" \
        AR="llvm-ar" \
        HOSTAR="llvm-ar" \
        HOSTAS="llvm-as" \
        HOSTNM="llvm-nm" \
        LD="ld.lld" 2>&1 | tee log.txt
    fi
}

post_build() {
    ## Check if the kernel binaries were built.
    if [ -f "$OUT_IMAGE" ]; then
        echo -e "\nINFO: Kernel compiled succesfully! Zipping up..."
    else
        echo -e "\nERROR: Kernel files not found! Compilation failed?"
        if [[ "$LOG_UPLOAD" == "1" ]]; then
            echo -e "\nINFO: Uploading log to bashupload.com\n"
            curl -T log.txt bashupload.com
        fi
        exit 1
    fi

    # If local AK3 copy exists, assume testing.
    if [[ -d "$AK3_DIR" ]]; then
        AK3_TEST=1  # Doesn't do anything from stock, but can be useful
        echo -e "\nINFO: AK3_TEST flag set because local AnyKernel3 dir was found"
    else
        if ! git clone -q --depth=1 -b "$AK3_BRANCH" "$AK3_URL" "$AK3_DIR"; then
            echo -e "\nERROR: Failed to clone AnyKernel3!"
            exit 1
        fi
    fi

    ## Copy the built binaries
    cp "$OUT_IMAGE" "$AK3_DIR"
    cp "$OUT_DTBO" "$AK3_DIR"

    ## Prepare kernel flashable zip
    cd "$AK3_DIR" || { echo "ERROR: Failed to cd to $AK3_DIR"; }
    git checkout "$AK3_BRANCH" &> /dev/null
    zip -r9 "$ZIP_PATH" * -x '*.git*' README.md *placeholder
    cd .. || { echo "ERROR: Failed to cd .. after zipping"; }
    rm -rf "$AK3_DIR"
    echo -e "\nINFO: Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
    echo "Zip: $ZIP_PATH"
    echo " "
    if [[ "$AK3_TEST" == "1" ]]; then
        echo -e "\nINFO: Skipping deletion of AnyKernel3 dir because test flag is set"
    else
        rm -rf "$AK3_DIR"
    fi
    cd "$KDIR"
}

upload() {
    if [[ "$LOG_UPLOAD" == "1" ]]; then
        echo -e "\nINFO: Uploading log to bashupload.com\n"
        curl -T log.txt bashupload.com
    fi
}

clean() {
    if [[ "$DO_CLEANUP" == "1" ]]; then
    echo -e "INFO: Cleaning after build, phase 1..."
    make O=out clean
    make O=out mrproper
    fi
 }

clean_tmp() {
    if [[ "$DO_CLEANUP" == "1" ]]; then
    echo -e "INFO: Cleaning after build, phase 2..."
    rm -f "$OUT_IMAGE"
    rm -f "$OUT_DTBO"
    fi
}

## Run build
# Do a clean build?
if [[ "$DO_CLEAN" == "1" ]]; then
    clean
fi
prep_build
build
post_build
clean_tmp

upload
