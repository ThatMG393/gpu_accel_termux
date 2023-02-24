#                                                                    
# █▀▀ █▀█ █░█     ▄▀█ █▀▀ █▀▀ █▀▀ █░   ░ ▄▀ █░█ █▀ █ █▄░█ █▀▀    ▀█ █ █▄░█ █▄▀ ▀▄
# █▄█ █▀▀ █▄█     █▀█ █▄▄ █▄▄ ██▄ █▄▄    ▀▄ █▄█ ▄█ █ █░▀█ █▄█    █▄ █ █░▀█ █░█ ▄▀
#
# AUTOMATED BY Thundersnow#7929, ThatMG393
# PATCHES MADE BY Thundersnow#7929

clear

# Possible values can only be 'enable', 'fix', and 'disable'
# Putting another values will just disable xf86bigfont
USE_XF86BF="fix"

# Yoink from UDroid
DIE() { echo -e "\e[1;31m${@}\e[0m"; exit 1 ;:; }
WARN() { echo -e "\e[1;33m${*}\e[0m";:; }

INFO_NewLineAbove() { echo ""; echo -e "\e[1;32m${*}\e[0m";:; }
INFO_NoNewLineAbove() { echo -e "\e[1;32m${*}\e[0m";:; }
INFO_NLANoNextLine() { echo ""; echo -n -e "\e[1;32m${*}\e[0m";:; }
INFO_NoNLANoNextLine() { echo -n -e "\e[1;32m${*}\e[0m";:; }

TITLE() { echo -e "\e[100m${*}\e[0m";:; }

if [ -d "/usr" ]; then DIE "Building inside a proot is not supported!"; fi

DEPENDENCIES="vulkaninfo git pv"

INFO_NewLineAbove "Checking for '$DEPENDENCIES'..."
WARN "If it hangs or takes too long, try to do it manually!"
WARN "pkg in $DEPENDENCIES"
for DEPENDENCY in $DEPENDENCIES; do
	if [[ ! -n $(command -v $DEPENDENCY) || $( $DEPENDENCY --help |& grep "(No such file or directory|Command not found)" | wc -l ) == 1 ]]; then
		INFO_NewLineAbove "Downloading '$DEPENDENCY'..."
		if [ $DEPENDENCY = "vulkaninfo" ]; then
			pkg in vulkan-tools -y &> /dev/null && {
				INFO_NoNewLineAbove "Success!" 
			} || {
				DIE "Failed!"
			}
		else
			pkg in $DEPENDENCY -y &> /dev/null && {
				INFO_NoNewLineAbove "Success!" 
			} || {
				DIE "Failed!"
			}
		fi
	else
		INFO_NoNewLineAbove "'$DEPENDENCY' already installed!"
	fi
done
INFO_NewLineAbove "Done!"

# Utils
RM_SILENT() { rm -rf "${*}" &> /dev/null ;:; }

MKDIR_NO_ERR() { if [ ! -d $1 ]; then mkdir -p $1; else WARN "Directory '$1' already exists!"; fi ;:; } 
CD_NO_ERR() { if [ ! -d $1 ]; then MKDIR_NO_ERR $1; fi; cd $1 ;:; } 

SIG_HANDLER() {
	clear
	DIE "Immediately cancelling as the user requested..."
}

trap 'SIG_HANDLER' SIGKILL SIGINT SIGTERM SIGHUP

echo ""
TITLE " █▀▀ █▀█ █░█     ▄▀█ █▀▀ █▀▀ █▀▀ █░   ░ ▄▀ █░█ █▀ █ █▄░█ █▀▀    ▀█ █ █▄░█ █▄▀ ▀▄  "
TITLE " █▄█ █▀▀ █▄█     █▀█ █▄▄ █▄▄ ██▄ █▄▄    ▀▄ █▄█ ▄█ █ █░▀█ █▄█    █▄ █ █░▀█ █░█ ▄▀  "
INFO_NewLineAbove "Activating GPU Acceleration (via Zink)"

INFO_NewLineAbove "Checking for requirements..."

#GPU_VULKAN_SUPPORT=$( getprop | grep "ro.hardware.vulkan" | grep -Po "\[[a-z]*\]" )
#echo -n "Is $GPU_VULKAN_SUPPORT supported?"
# if [[ "$GPU_VULKAN_SUPPORT" = "[mali]" || "$GPU_VULKAN_SUPPORT" = "[qualcomm]" || "$GPU_VULKAN_SUPPORT" = "[powervr]" ]]; then
#	echo " yes"
#else
#	echo " no"
#	exit 1
#fi

GPU_REQ_FEATURES=$( vulkaninfo | grep -oE '(VK_KHR_maintenance1|VK_KHR_create_renderpass2|VK_KHR_imageless_framebuffer|VK_KHR_descriptor_update_template|VK_KHR_timeline_semaphore|VK_EXT_transform_feedback)' | wc -l )

INFO_NLANoNextLine "Does GPU has feature VK_KHR_maintenance1, VK_KHR_create_renderpass2, VK_KHR_imageless_framebuffer, VK_KHR_descriptor_update_template, VK_KHR_timeline_semaphore, and VK_EXT_transform_feedback?"
if [[ $GPU_REQ_FEATURES == 6 ]]; then
	echo " yes"
elif [[ $GPU_REQ_FEATURES == 5 ]]; then
	echo ""
	INFO_NewLineAbove "Wait for another script that installs the old supported version..."
	exit 1
else
	echo " no"
	
	DIE "Double check using 'vulkaninfo | grep VK_KHR'"
	exit 1
fi

GPU_DRIVER_VERSION=$( vulkaninfo | grep driverVersion | cut -d ' ' -f7 | tr -d '.' )

#FIXME: Add Qualcomm Version compare logic
INFO_NLANoNextLine "Is the GPU driver version greater than or equal to '38.1.0'? "
if [ $GPU_DRIVER_VERSION -ge 3810 ]; then
	echo " yes"
	
	INFO_NewLineAbove "If you GPU Model is made by Qualcomm or PowerVR then try to increase the '3810' in the script. (Line 108, near '-ge')"
	DIE "GPU driver version >= 38.1.0 is unsupported!"
else
	echo " no"
fi

INFO_NewLineAbove "You passed the requirements, congrats! Prepare for automatic install. Please keep Termux in focus and don't close Termux..."

#### MAIN LOGIC ####

MAIN_FOLDER="$HOME/gpu_accel"
MKDIR_NO_ERR $MAIN_FOLDER

TMP_FOLDER="$MAIN_FOLDER/tmp"

MESA_PATCH_FILE="$MAIN_FOLDER/mesa20230212.patch"
XSERVER_PATCH_FILE="$MAIN_FOLDER/xserver.patch"
VIRGL_DIFF_FILE="$MAIN_FOLDER/virglrenderer.diff"

PATCHES_TAR_GZ="$MAIN_FOLDER/patches.tar.gz"

INFO_NewLineAbove "Checking for patches and diff files..."

[[ ! -f $MESA_PATCH_FILE || ! -f $XSERVER_PATCH_FILE || ! -f $VIRGL_DIFF_FILE ]] && {
	INFO_NewLineAbove "Fetching & Extracting 'patches.tar.gz'"
	WARN "This might take a while..."
	
	RM_SILENT $MESA_PATCH_FILE $XSERVER_PATCH_FILE $VIRGL_DIFF_FILE &> /dev/null
	
	CD_NO_ERR $MAIN_FOLDER
	# [ $( gzip -t $PATCHES_TAR_GZ && $? ) != 0 ] && {
	[ ! -f $PATCHES_TAR_GZ ] && {
		RM_SILENT $PATCHES_TAR_GZ &> /dev/null # Sanity check
		wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/ThatMG393/gpu_accel_termux/master/patches.tar.gz 2>&1 && {
			INFO_NoNewLineAbove "Success! (1/2)"
		} || {
			DIE "Failed to fetch 'patches.tar.gz'. Is 'wget' installed? Try doing 'yes | pkg up -y && pkg in wget -y'"
		}
	}
	
	pv -p --timer --rate --bytes $PATCHES_TAR_GZ | tar -xz && {
		INFO_NoNewLineAbove "\33[2K\rSuccess! (2/2)"
	} || {
		DIE "Failed to extract 'patches.tar.gz'. Is 'wget' and 'tar' installed? Try re-running the script."
	}
} || {
	INFO_NoNewLineAbove "All found!"
}

echo ""
WARN "Auto compile & install is starting in 4s, interrupt (Ctrl-C) now if ran accidentally"

sleep 4
clear

TITLE "AUTO INSTALLATION STARTED"

INFO_NewLineAbove "Looking for x11-repo"; pkg install -y x11-repo -y &> /dev/null
INFO_NoNewLineAbove "Installing build systems & binaries"; pkg install -y clang lld binutils cmake autoconf automake libtool '*ndk*' make python git libandroid-shmem-static 'vulkan*' ninja llvm bison flex libx11 xorgproto libdrm libpixman libxfixes libjpeg-turbo xtrans libxxf86vm xorg-xrandr xorg-font-util xorg-util-macros libxfont2 libxkbfile libpciaccess xcb-util-renderutil xcb-util-image xcb-util-keysyms xcb-util-wm xorg-xkbcomp xkeyboard-config libxdamage libxinerama -y  &> /dev/null
INFO_NoNewLineAbove "Installing meson & mako"; pip install meson mako &> /dev/null

clear

[ -d $TMP_FOLDER ] && {
	INFO_NoNLANoNextLine "The repositories folder already exists do you want to re-clone the repositories? (y|n) "
	
	read -p "" ANSWER
	
	case $ANSWER in
		y | Y | yes ) RM_SILENT $TMP_FOLDER ;;
		n | N | no  ) INFO_NewLineAbove "Skipping..." ;;
	esac
}

CD_NO_ERR $TMP_FOLDER

clear
INFO_NoNewLineAbove "Cloning repositories..."

INFO_NewLineAbove "Cloning 'mesa'"
WARN "This repository takes very long to clone, don't panic!"
git clone "https://gitlab.freedesktop.org/mesa/mesa.git"
INFO_NoNewLineAbove "Cloning 'virglrenderer'"
git clone -q "https://gitlab.freedesktop.org/virgl/virglrenderer.git"

INFO_NoNewLineAbove "Cloning 'libxshmfence_v1.3'"
git clone -q -b libxshmfence-1.3 "https://gitlab.freedesktop.org/xorg/lib/libxshmfence.git"
INFO_NoNewLineAbove "Cloning 'libepoxy_v1.5.10'"
git clone -q -b 1.5.10 "https://github.com/anholt/libepoxy.git"
INFO_NoNewLineAbove "Cloning 'wayland_v1.21.0'"
git clone -q -b 1.21.0 "https://gitlab.freedesktop.org/wayland/wayland.git"
INFO_NoNewLineAbove "Cloning 'wayland-protocols_v1.26'"
git clone -q -b 1.26 "https://gitlab.freedesktop.org/wayland/wayland-protocols.git"
INFO_NoNewLineAbove "Cloning 'libsha1_v0.3'"
git clone -q -b 0.3 "https://github.com/dottedmag/libsha1.git"
INFO_NoNewLineAbove "Cloning 'xorg-server_v1.20.14'"
git clone -q -b xorg-server-1.20.14 "https://gitlab.freedesktop.org/xorg/xserver.git"

INFO_NewLineAbove "DONE!"
clear

# set -e # Late enable

#compile libxshmfence
clear
TITLE "Compiling libxshmfence... (1/8)"
echo ""

cd $TMP_FOLDER/libxshmfence
sed -i s/values.h/limits.h/ ./src/xshmfence_futex.h

RM_SILENT $PREFIX/lib/libxshmfence*

./autogen.sh --prefix=$PREFIX --with-shared-memory-dir=$TMPDIR
make -s -j8 install CPPFLAGS=-DMAXINT=INT_MAX

#compile mesa
clear
TITLE "Compiling & Patching mesa... (2/8)"
WARN "Prepare for LAG!"
echo ""

cd $TMP_FOLDER/mesa
[ ! -f $MESA_PATCH_FILE ] && {
	DIE "Mesa patch file not found! Try re-running the script..."
}
git checkout -f main
git apply $MESA_PATCH_FILE

MKDIR_NO_ERR b
CD_NO_ERR b

LDFLAGS='-l:libandroid-shmem.a -llog' meson .. -Dprefix=$PREFIX -Dplatforms=x11 -Dgbm=enabled -Dgallium-drivers=zink,swrast -Dllvm=enabled -Dvulkan-drivers='' -Dcpp_rtti=false -Dc_args=-Wno-error=incompatible-function-pointer-types -Dbuildtype=release

RM_SILENT $PREFIX/lib/libglapi.so*
RM_SILENT $PREFIX/lib/libGL.so*
RM_SILENT $PREFIX/lib/libGLES*
RM_SILENT $PREFIX/lib/libEGL*
RM_SILENT $PREFIX/lib/libgbm*

ninja install

#compile libepoxy
clear
TITLE "Compiling libepoxy... (3/8)"
echo ""

cd $TMP_FOLDER/libepoxy

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dprefix=$PREFIX -Dbuildtype=release -Dglx=yes -Degl=yes -Dtests=false -Dc_args=-U__ANDROID__ ..

RM_SILENT $PREFIX/lib/libepoxy*

ninja install

#compile virglrenderer
clear
TITLE "Compiling & Patching virglrenderer... (4/8)"
echo ""

cd $TMP_FOLDER/virglrenderer

[ ! -f $VIRGL_PATCH_FILE ] && {
	DIE "VirGL diff file not found! Try re-running the script..."
}
git checkout -f master
git apply $VIRGL_DIFF_FILE

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dbuildtype=release -Dprefix=$PREFIX -Dplatforms=egl ..

RM_SILENT $PREFIX/lib/libvirglrenderer*

ninja install

#compile wayland
clear
TITLE "Compiling wayland... (5/8)"
echo ""

RM_SILENT $PREFIX/lib/libwayland*

cd $TMP_FOLDER/wayland

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dprefix=$PREFIX -Dtests=false -Ddocumentation=false -Dbuildtype=release ..
ninja install

#compile wayland-protocols
clear
TITLE "Compiling wayland-protocols... (6/8)"
echo ""

RM_SILENT /data/data/com.termux/files/usr/lib/pkgconfig/wayland-protocols.pc

cd $TMP_FOLDER/wayland-protocols

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dprefix=$PREFIX -Dtests=false -Dbuildtype=release ..
ninja install

#compile libsha1
clear
TITLE "Compiling libsha1... (7/8)"
echo ""

cd $TMP_FOLDER/libsha1

RM_SILENT $PREFIX/lib/libsha1*

./autogen.sh --prefix=$PREFIX
make -s -j8 install

#compile Xwayland
clear
TITLE "Compiling & Patching xserver... (8/8)"
echo ""

cd $TMP_FOLDER/xserver
[ ! -f $XSERVER_PATCH_FILE ] && {
	DIE "xserver patch file not found! Try re-running the script..."
}
git checkout -f master
git apply $XSERVER_PATCH_FILE

[[ "$USE_XF86BF" = "enable" || "$USE_XF86BF" = "fix" ]] && {
	./autogen.sh --enable-mitshm --enable-xcsecurity --enable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
} || {
	./autogen.sh --enable-mitshm --enable-xcsecurity --disable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
}

[ "$USE_XF86BF" = "fix" ] && {
	make -s -j8 install LDFLAGS='-fuse-ld=lld /data/data/com.termux/files/usr/lib/libandroid-shmem.a -llog' CPPFLAGS=-DSHMLBA=4096 # CHANGE THIS IF CRASHING OR SMTH
} || {
	make -s -j8 install LDFLAGS='-fuse-ld=lld /data/data/com.termux/files/usr/lib/libandroid-shmem.a -llog'
}

clear
TITLE "DONE!"
INFO_NewLineAbove "Build success!"
INFO_NewLineAbove "Termux-X11 is recommended when using this!"

WARN "DONT UPGRADE ANY OF THE BINARIES USING ANY PACKAGE MANAGER"
WARN "OR YOU WILL NEED TO RECOMPILE AGAIN!"

INFO_NewLineAbove "Script signing off..."
exit 0
