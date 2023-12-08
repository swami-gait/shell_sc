VERSION=0.3 #Monday 06 November 2023
WORKSPACE=$(pwd)
CHIPCODE_ZIP=ipq9574-rdk-12-2-0_qca_oem-r00011.1a-1b25e33101663c8227ad82062a2ef0202620b41b.zip
CHIPCODE=$(basename $CHIPCODE_ZIP .zip)
MACHINE_NAME=ipq95xx_64-rdk-broadband
OE_BDIR=build-$MACHINE_NAME
QRDK_TOPDIR=2022q4_dunfell
ONEFW_TOPDIR=ofw
set -x
setup_ubuntu_build_machine() {
    sudo apt-get install gcc g++ binutils patch bzip2 flex make gettext \
        pkg-config unzip zlib1g-dev libc6-dev subversion libncurses5-dev gawk \
        sharutils curl libxml-parser-perl ocaml-nox ocaml ocaml-findlib \
        python3-yaml libssl-dev libfdt-dev bison texi2html diffstat dos2unix \
        texinfo chrpath bc gcc-multilib git build-essential autoconf libtool \
        libncurses-dev gperf lib32z1 libc6-i386 g++-multilib python3-git \
        coccinelle
    sudo apt-get install device-tree-compiler u-boot-tools
    wget http://launchpadlibrarian.net/366014597/make_4.1-9.1ubuntu1_amd64.deb
    sudo dpkg -i make_4.1-9.1ubuntu1_amd64.deb
    rm make_4.1-9.1ubuntu1_amd64.deb
    sudo apt-get install u-boot-tools
    sudo apt-get install device-tree-compiler
    sudo apt-get install libfdt-dev
    sudo apt-get install python2.7
}
setup_chipcode() {
    [ -e $CHIPCODE ] && echo "Already chipcode setup done" && return
    if [ -e $CHIPCODE_ZIP ]; then
        unzip $CHIPCODE_ZIP
    else
        echo "No Chipcode $CHIPCODE_ZIP Found"
        exit 0
    fi
    cd $CHIPCODE &&
        ln -sf NHSS.RDK.12.2.0/apss_proc/ apss_proc &&
        cd ..
}
repo_sync_qrdk() {
    [ -e $CHIPCODE/.repo ] && echo "Already qrdk repo sync done" && return
    cd $CHIPCODE
    repo init -u https://git.codelinaro.org/clo/qrdk/releases/manifest/qrdk -b release -m AU_LINUX_BASE_QRDK_NHSS.RDK.12.2.0.R2_TARGET_ALL.12.2.002.446.015.xml --repo-url=https://git.codelinaro.org/clo/la/tools/repo.git --repo-branch=qc-stable --no-clone-bundle ||
        sed -i -e 's/\(.*from formatter.*\)/#\1/' .repo/repo/subcmds/help.py &&
        repo init -u https://git.codelinaro.org/clo/qrdk/releases/manifest/qrdk -b release -m AU_LINUX_BASE_QRDK_NHSS.RDK.12.2.0.R2_TARGET_ALL.12.2.002.446.015.xml --repo-url=https://git.codelinaro.org/clo/la/tools/repo.git --repo-branch=qc-stable --no-clone-bundle
    cd ..
}
repo_sync_rdkb_llc() {
    mkdir $QRDK_TOPDIR
    cd $QRDK_TOPDIR
    repo init -u https://code.rdkcentral.com/r/rdkcmf/manifests -m rdkb-extsrc.xml -b rdkb-2022q4-dunfell --repo-url=https://git.codelinaro.org/clo/la/tools/repo.git --repo-branch=qc-stable --no-clone-bundle
    cp $WORKSPACE/$CHIPCODE/.repo/manifests/AU_LINUX_BASE_QRDK_NHSS.RDK.12.2.0.R2_TARGET_ALL.12.2.002.446.015.xml .repo/manifests/oe-ipq.xml
    cd .repo/manifests
    sed -i '/<default/d' oe-ipq.xml
    sed -i "/<project/ s/^\(.*\)\( revision\)/\1 remote=\"clo\"\2/" oe-ipq.xml
    sed -i 's/path="qrdk\//path="/g' oe-ipq.xml
    sed -i '/name="oe-layers.xml"/a \ \ <include name="oe-ipq.xml"/>' rdkb-extsrc.xml
    cd ..
    repo sync -j $(nproc) --no-clone-bundle --no-tags
    if [ $? != 0 ]; then
        echo "Repo sync failed"
        exit 0
    fi
    cd ..
}
setup_qrdk_downloads() {
    BLD_TOPDIR=$1
    [ -e $BLD_TOPDIR/downloads/BIN-EIP197.AL.3.3.tar.bz2.done ] && echo "Already qrdk downloads setup done" && return
    [ ! -d $WORKSPACE/$BLD_TOPDIR ] && mkdir $WORKSPACE/$BLD_TOPDIR
    cd $WORKSPACE/$BLD_TOPDIR
    mkdir downloads
    cd downloads
    cp $WORKSPACE/$CHIPCODE/WLAN.HK.2.9/wlan_proc/pkg/wlan_proc/bin/QCA8074_v1.0/qca-wifi-fw-QCA8074_v1.0-WLAN.HK.2.9-*.tar.bz2 .
    cp $WORKSPACE/$CHIPCODE/WLAN.HK.2.9/wlan_proc/src/components/QCA8074_v1.0/qca-wifi-fw-src-component-cmn-WLAN.HK.2.9-*.tgz .
    cp -rf $WORKSPACE/$CHIPCODE/NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qca-nss-fw-eip-al/BIN-EIP*.AL.* .
    touch qca-wifi-fw-QCA8074_v1.0-WLAN.HK.2.9-01979-QCAHKSWPL_SILICONZ-1.tar.bz2.done
    touch qca-wifi-fw-src-component-cmn-WLAN.HK.2.9-01979-QCAHKSWPL_SILICONZ-1.tgz.done
    touch BIN-EIP197.AL.3.3.tar.bz2.done
    cd ..
}
extract_qrdk_from_chipcode() {
    BLD_TOPDIR=$1
    [ -e ../$BLD_TOPDIR/rdkb/devices/ipq ] && echo "Already chipcode folders are copied to build" && return
    cd $WORKSPACE/$CHIPCODE
    cp -rf NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qrdk/meta-cmf-ipq ../$BLD_TOPDIR/
    cp -rf NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qrdk/meta-ipq ../$BLD_TOPDIR/
    cp -rf NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qrdk/wifi ../$BLD_TOPDIR/
    cp -rf NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qrdk/common ../$BLD_TOPDIR/
    if [ ! -e ../$BLD_TOPDIR/rdkb/devices ]; then
        cp -rf NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qrdk/rdkb ../$BLD_TOPDIR/
    else
        cp -rf NHSS.RDK.12.2.0/apss_proc/out/proprietary/HY11_1/qrdk/rdkb/devices/ipq ../$BLD_TOPDIR/rdkb/devices/
    fi
    cd ..
}
change_qrdk_pkg_rev() {
    BLD_TOPDIR=$1
    [ "$PWD" != "$WORKSPACE/$BLD_TOPDIR" ] && cd $WORKSPACE/$BLD_TOPDIR
    if ! grep security-assurance-test meta-ipq/recipes-core/images/ipq-pkgs.inc; then
        echo "Already revs were cleared" && return
    fi
    sed -i 's/WLAN.HK.2.9-01190-QCAHKSWPL_SILICONZ-1/WLAN.HK.2.9-01979-QCAHKSWPL_SILICONZ-1/g' meta-ipq/recipes-qcawififw/qca-wififw/qca-wififw.bb
    sha=$(sha256sum downloads/qca-wifi-fw-QCA8074_v1.0-WLAN.HK.2.9-01979-QCAHKSWPL_SILICONZ-1.tar.bz2 | cut -d' ' -f1)
    sed -i "s/7d8aa1777385ce6a11784d72d1b2f0cc44aae84f98824358a412ddbfb81b6e3b/${sha}/g" meta-ipq/recipes-qcawififw/qca-wififw/qca-wififw.bb
    sed 's/${FWA_PKGS}//g' -i meta-ipq/recipes-core/images/ipq-pkgs.inc
    sed 's/${AFC_PKGS}//g' -i meta-ipq/recipes-core/images/ipq-pkgs.inc
    sed -i 's/i2c-rw-utils //g' meta-ipq/recipes-core/images/ipq-pkgs.inc
    sed -i 's/security-assurance-test//g' meta-ipq/recipes-core/images/ipq-pkgs.inc
    cd ..
}
build_qrdk() {
    cd $QRDK_TOPDIR
    sudo bash meta-ipq/scripts/setup_qrdk.sh
    setup_ubuntu_build_machine
    dos2unix rdkb/components/opensource/ccsp/RdkWanManager/source/WanManager/wanmgr_sysevents.c
    source meta-cmf-ipq/setup-environment
    umask 022
    bitbake rdk-generic-broadband-image
    cd ..
}
build_single_image() {
    cd $CHIPCODE
    mkdir -p $CHIPCODE/common/build/ipq_x64
    mkdir apss_proc/out/rdk-generic-broadband-image
    cp -rf $WORKSPACE/$QRDK_TOPDIR/build-ipq95xx_64-rdk-broadband/tmp/deploy/images apss_proc/out/rdk-generic-broadband-image
    cp -rf $WORKSPACE/$QRDK_TOPDIR/boot/u-boot-2016/tools/pack.py apss_proc/out/
    cp -rf ./apss_proc/out/proprietary/HY11_1/meta-tools apss_proc/out/
    cp -rf ./apss_proc/out/proprietary/HY11_1/jtag-scripts apss_proc/out/
    cp -rf ../TMEL.WNS/firmware/signed/tmel-ipq95xx-firmware.elf common/build/ipq_x64
    cd $CHIPCODE/common/build/
    export BLD_ENV_BUILD_ID=S
    python2.7 update_common_info.py 64
}
repo_sync_onefw() {
    [ ! -d $WORKSPACE/$ONEFW_TOPDIR ] && mkdir $WORKSPACE/$ONEFW_TOPDIR
    cd $WORKSPACE/$ONEFW_TOPDIR
    repo init --repo-branch=repo-1 -u https://github.com/lgirdk/manifests-ofw.git -b ofw-2302 -m oe31-open.xml ||
        sed -i -e 's/\(.*from formatter.*\)/#\1/' .repo/repo/subcmds/help.py &&
        repo init --repo-branch=repo-1 -u https://github.com/lgirdk/manifests-ofw.git -b ofw-2302 -m oe31-open.xml
    cp $WORKSPACE/$CHIPCODE/.repo/manifests/AU_LINUX_BASE_QRDK_NHSS.RDK.12.2.0.R2_TARGET_ALL.12.2.002.446.015.xml .repo/manifests/oe-ipq.xml
    cd .repo/manifests
    sed -i '/<default/d' oe-ipq.xml
    sed -i "/<project/ s/^\(.*\)\( revision\)/\1 remote=\"clo\"\2/" oe-ipq.xml
    sed -i 's/path="qrdk\//path="/g' oe-ipq.xml
    cd ..
    sed -i '/<\/manifest>/i <include name="oe-ipq.xml"\/> ' manifest.xml
    cd ..
    repo sync -j $(nproc) --no-clone-bundle --current-branch --no-tags
}
collate_qrdk_to_onefw() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    [ ! -e meta-cmf-ipq ] && echo "Already meta-cmf-ipq moved" && return
    mv meta-ipq meta-ipq-bk
    mkdir meta-ipq
    rsync -avhu --progress meta-ipq-bk/ meta-ipq
    rsync -avhu --progress meta-cmf-ipq/ meta-ipq
    mv meta-ipq-bk ../
    mv meta-cmf-ipq ../
}
ccsp_hotspot_patch() {
    if [ ! -f meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot-kmod ] && [ ! -f meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot-kmod.bbappend ]; then
        mkdir meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot-kmod
        cat <<EOF >meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot-kmod/0001-pInDev_variable_declaration.patch
diff --git a/mtu_mod_br.c b/mtu_mod_br.c
index 37d49d8..4140da5 100644
--- a/mtu_mod_br.c
+++ b/mtu_mod_br.c
@@ -308,7 +308,7 @@ static void mtu_mod_send_icmp_too_big_frame(const struct net_device *pInDev, str
     /*assign necessary fields for icmp skb*/
     skb_put(icmpSkb, pDst - skb_mac_header(icmpSkb));
     icmpSkb->data = skb_mac_header(icmpSkb);
-    icmpSkb->dev = pInDev;
+    icmpSkb->dev = (struct net_device *) pInDev;
     icmpSkb->protocol = htons(ETH_P_IP);
     /*send this skb out*/
EOF
        echo "FILESEXTRAPATHS_prepend := \"\${THISDIR}/\${BPN}:\"
SRC_URI += \"file://0001-pInDev_variable_declaration.patch\" 
" >>meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot-kmod.bbappend
    else
        echo "ccsp-hotspot-kmod patch already applied"
    fi
}
ccsp_misc_patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ -d "meta-ipq/recipes-ccsp/ccsp/ccsp-misc" ] && grep -q "specifier" "meta-ipq/recipes-ccsp/ccsp/ccsp-misc.bbappend"; then
        echo "ccsp misc patch is already applied"
    else
        mkdir meta-ipq/recipes-ccsp/ccsp/ccsp-misc
        cat <<EOF >meta-ipq/recipes-ccsp/ccsp/ccsp-misc/0001-format-specifier-error.patch
diff --git a/source/dhcp_client_utils/dhcpv4_client_utils.c b/source/dhcp_client_utils/dhcpv4_client_utils.c
index 23b0ed1..5e74f65 100644
--- a/source/dhcp_client_utils/dhcpv4_client_utils.c
+++ b/source/dhcp_client_utils/dhcpv4_client_utils.c
@@ -133,7 +133,7 @@ static int prepare_dhcp125_optvalue(char *options_125, const int length)
         if ((len > 0xFF) || !verifyBufferSpace(length, opt_len, 2 + 2 + (2 * len))) {
             return -1;
         }
-        opt_len += sprintf(options + opt_len, "%02x%02x", subopt, len);
+        opt_len += sprintf(options + opt_len, "%02x%02lx", subopt, len);
         opt_len = writeTOHexFromAscii(options, length, opt_len, CONFIG_VENDOR_ID);
     }
     /*
@@ -149,7 +149,7 @@ static int prepare_dhcp125_optvalue(char *options_125, const int length)
             if ((len > 0xFF) || !verifyBufferSpace(length, opt_len, 2 + 2 + (2 * len))) {
               return -1;
         }
-            opt_len += sprintf(options + opt_len, "%02x%02x", subopt, len);
+            opt_len += sprintf(options + opt_len, "%02x%02lx", subopt, len);
             opt_len = writeTOHexFromAscii(options, length, opt_len, buf);
         }
     }
@@ -171,7 +171,7 @@ static int prepare_dhcp125_optvalue(char *options_125, const int length)
             if ((len > 0xFF) || !verifyBufferSpace(length, opt_len, 2 + 2 + (2 * len))) {
               return -1;
         }
-            opt_len += sprintf(options + opt_len, "%02x%02x", subopt, len);
+            opt_len += sprintf(options + opt_len, "%02x%02lx", subopt, len);
             opt_len = writeTOHexFromAscii(options, length, opt_len, buf);
         }
     }
@@ -193,7 +193,7 @@ static int prepare_dhcp125_optvalue(char *options_125, const int length)
             if ((len > 0xFF) || !verifyBufferSpace(length, opt_len, 2 + 2 + (2 * len))) {
                 return -1;
             }
-            opt_len += sprintf(options + opt_len, "%02x%02x", subopt, len);
+            opt_len += sprintf(options + opt_len, "%02x%02lx", subopt, len);
             opt_len = writeTOHexFromAscii(options, length, opt_len, buf);
         }
     }
@@ -203,7 +203,7 @@ static int prepare_dhcp125_optvalue(char *options_125, const int length)
         return -1;
     }
     len = strlen(options);
-    snprintf(options_125,length,"%s%02x%s",duid,(len/2),options);
+    snprintf(options_125,length,"%s%02lx%s",duid,(len/2),options);
     return 0;
 }
EOF
        echo "FILESEXTRAPATHS_prepend := \"\${THISDIR}/\${BPN}:\"
SRC_URI += \"file://0001-format-specifier-error.patch\"
do_install_append () {
        install -d \${D}/etc/
        install -m 755 \${S}/source/bridge_utils/scripts/migration_to_psm.sh \${D}/etc/
}
FILES_\${PN} += \"/usr/ccsp\"
" >>meta-ipq/recipes-ccsp/ccsp/ccsp-misc.bbappend
    fi
}
hal_ethsw_generic_fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if grep -q "CcspHalEthSwGetEEEPortEnable" "rdkb/devices/ipq/hal/hal-ethsw/source/hal-ethsw/ccsp_hal_ethsw.c"; then
        echo "patch is already applied in hal ethsw generic"
    else
        echo "
int CcspHalEthSwGetEEEPortEnable (CCSP_HAL_ETHSW_PORT PortId, BOOLEAN *enable)
    {
        *enable = FALSE;
        return RETURN_OK;
    }
int CcspHalEthSwSetEEEPortEnable (CCSP_HAL_ETHSW_PORT PortId, BOOLEAN enable)
    {
        return RETURN_OK;
    }
" >>rdkb/devices/ipq/hal/hal-ethsw/source/hal-ethsw/ccsp_hal_ethsw.c
    fi
}
qca_wifi_fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i "121,125s/^/# /" wifi/qca-wifi/os/linux/Makefile
    echo '
	for var in $(strip $(COPTS));\
        do \
        echo $$var | grep '\''\-D'\'' > /dev/null && echo "#ifndef $$(echo $$var | sed -e 's:-D::'| cut -f 1 -d=)" >> $(DEPTH)/include/ieee80211_external_config.h.tmp &&\
        echo "$$(echo $$var | sed -e "'s:-D:#define :'" -e "'s:=: :'")" >> $(DEPTH)/include/ieee80211_external_config.h.tmp &&\
        echo "#endif" >> $(DEPTH)/include/ieee80211_external_config.h.tmp ;\
        done
        ' >tmp_makefile_fix
    sed -i '125r tmp_makefile_fix' wifi/qca-wifi/os/linux/Makefile
    rm -rf tmp_makefile_fix
    sed -i 's|open(filename, O_WRONLY \| O_CREAT)|open(filename, O_WRONLY \| O_CREAT, 0666)|g' wifi/qca-wifi/component_dev/tools/linux/cfr_test_app.c
    cd wifi/qca-wifi/
    grep -rli '\-Werror' * | xargs -i@ sed -i 's/-Werror//g' @
    cd ../../
    sed -i 's/-Werror//' common/hyfi/libwpa2/Makefile
}
hal_platform_generic_fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if grep -q "platform_hal_GetCustomerIndex" "rdkb/devices/ipq/hal/hal-platform/source/hal-platform/platform_hal.c"; then
        echo "hal_platform_generic patch is already applied"
    else
        echo '
INT platform_hal_GetCustomerIndex(void)
{
        return 0;
}
INT platform_hal_GetProductClass (char *pValue)
{
        return 0;
}
' >>rdkb/devices/ipq/hal/hal-platform/source/hal-platform/platform_hal.c
    fi
}
halinterface_fix() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i -e 's/meta-cmf-ipq/meta-ipq/' meta-ipq/recipes-ccsp/ccsp/halinterface.bbappend
    sed -i -e 's/addtask/\#addtask/g' meta-ipq/recipes-ccsp/ccsp/halinterface.bbappend
    if [ ! -f meta-ipq/recipes-ccsp/ccsp/0006-halinterface-wifi-radius-setting.patch ]; then
        cat <<EOF >meta-ipq/recipes-ccsp/ccsp/0006-halinterface-wifi-radius-setting.patch
diff --git a/wifi_hal_ap.h b/wifi_hal_ap.h
index cb1c48a..f1dfe48 100644
--- a/wifi_hal_ap.h
+++ b/wifi_hal_ap.h
@@ -331,6 +331,8 @@ typedef struct _wifi_radius_setting_t
      INT  RadiusServerRequestTimeout;   /**< Radius request timeout in seconds after which the request must be retransmitted for the # of retries available.     */
      INT  PMKLifetime;                  /**< Default time in seconds after which a Wi-Fi client is forced to ReAuthenticate (def 8 hrs)      */
      INT  MaxAuthenticationAttempts;    /**< Indicates the # of time, a client can attempt to login with incorrect credentials. When this limit is reached, the client is blacklisted and not allowed to attempt loging into the network. Settings this parameter to 0 (zero) disables the blacklisting feature. */
+     BOOL PMKCaching;                   /**< Enable or disable caching of PMK.     */
+     INT  PMKCacheInterval;             /**< Time interval in seconds after which the PMKSA (Pairwise Master Key Security Association) cache is purged (def 5 minutes).     */
      INT  BlacklistTableTimeout;        /**< Time interval in seconds for which a client will continue to be blacklisted once it is marked so.  */
      INT  IdentityRequestRetryInterval; /**< Time Interval in seconds between identity requests retries. A value of 0 (zero) disables it    */
      INT  QuietPeriodAfterFailedAuthentication;  /**< The enforced quiet period (time interval) in seconds following failed authentication. A value of 0 (zero) disables it. */
EOF
        echo "
SRC_URI += \"file://0006-halinterface-wifi-radius-setting.patch\"
       " >>meta-ipq/recipes-ccsp/ccsp/halinterface.bbappend
    else
        echo "halinterface patch already applied"
    fi
}
ccsp-lm-lite_patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if grep -q " #SRC_URI += " "meta-ipq/recipes-ccsp/ccsp/ccsp-lm-lite.bbappend" && grep -q " #addtask " "meta-ipq/recipes-ccsp/ccsp/ccsp-lm-lite.bbappend"; then
        echo "ccsp-lm-lite patch is already applied"
    else
        sed -i -e '/SRC_URI +=/ s/^#*/#/' meta-ipq/recipes-ccsp/ccsp/ccsp-lm-lite.bbappend
        sed -i -e 's/utopia-headers/ utopia-headers/' meta-ipq/recipes-ccsp/ccsp/ccsp-lm-lite.bbappend
        sed -i -e 's/addtask/\#addtask/g' meta-ipq/recipes-ccsp/ccsp/ccsp-lm-lite.bbappend
    fi
}
ccsp_cr_fix() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i -e 's/SRC_URI +=/\#SRC_URI +=/g' meta-ipq/recipes-ccsp/ccsp/ccsp-cr.bbappend
}
ccsp_p_and_m_patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ -d "meta-ipq/recipes-ccsp/ccsp/ccsp-p-and-m" ] && grep -q "{BPN}" "meta-ipq/recipes-ccsp/ccsp/ccsp-p-and-m.bbappend"; then
        echo "ccsp p-and-m patch is already applied"
    else
        mkdir meta-ipq/recipes-ccsp/ccsp/ccsp-p-and-m
        sed -i "s\{THISDIR}\{THISDIR}/\${BPN}\g" meta-ipq/recipes-ccsp/ccsp/ccsp-p-and-m.bbappend
        sed -i "s\rdkb/components/opensource/ccsp/CcspPandM\src/ccsp-p-and-m\g" meta-ipq/recipes-ccsp/ccsp/ccsp-p-and-m.bbappend
        chmod +x $WORKSPACE/components/ccsp-p-and-m-fixes.sh
        bash $WORKSPACE/components/ccsp-p-and-m-fixes.sh
    fi
}
rdk_wanmanager_patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ -d "meta-ipq/recipes-ccsp/ccsp/rdk-wanmanager" ] && grep -q "{BPN}" "meta-ipq/recipes-ccsp/ccsp/rdk-wanmanager.bbappend"; then
        echo "rdk wanmanager patch is already applied"
    else
        mkdir meta-ipq/recipes-ccsp/ccsp/rdk-wanmanager
        sed -i "s\{THISDIR}\{THISDIR}/\${BPN}\g" meta-ipq/recipes-ccsp/ccsp/rdk-wanmanager.bbappend
        sed -i "s\rdkb/components/opensource/ccsp/RdkWanManager\src/rdk-wanmanager/\g" meta-ipq/recipes-ccsp/ccsp/rdk-wanmanager.bbappend
        chmod +x $WORKSPACE/components/rdk-wanmanager-fixes.sh
        bash $WORKSPACE/components/rdk-wanmanager-fixes.sh
    fi
}
utopia_patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ -d "meta-ipq/recipes-ccsp/util/utopia" ] && grep -q "undefined_error_fix_utopia" "meta-ipq/recipes-ccsp/util/utopia.bbappend"; then
        echo "utopia patch is already applied"
    else
        sed -i '/0002-service-lan.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0004-service-lan.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0003-service-bridge.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0001-interface-functions.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0001-utopia-wlan.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0002-service-dhcpv6-client-arm.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0001-service-dhcpv6-client-arm.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0001-fix-musl-build.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0001-enable-pppoe.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/0002-service-forwarding.patch/d' meta-ipq/recipes-ccsp/util/utopia.bbappend
        sed -i '/file:\/\/0014-service-dhcp-server-fix.patch/afile://undefined_error_fix_utopia.patch \\' meta-ipq/recipes-ccsp/util/utopia.bbappend
        rm -rf meta-ipq/recipes-ccsp/util/utopia/0*
        chmod +x $WORKSPACE/components/utopia-fixes.sh
        bash $WORKSPACE/components/utopia-fixes.sh
    fi
}
ccsp-eth-agent-patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ -d "meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent" ] && grep -q "{BPN}" "meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend"; then
        echo "ccsp-eth-agent patch is already applied"
    else
        mkdir meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent
        sed -i "s\{THISDIR}\{THISDIR}/\${BPN}\g" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "s\rdkb/components/opensource/ccsp/CcspEthAgent\src/ccsp-eth-agent/\g" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "2s/^/CFLAGS_append = \" \$\{@bb\.utils\.contains\('DISTRO_FEATURES', 'safec',  ' \`pkg-config --cflags libsafec\`', '-fPIC', d\)\}\"\\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "3s/^/LDFLAGS_append = \" \$\{@bb\.utils\.contains\('DISTRO_FEATURES', 'safec', ' \`pkg-config --libs libsafec\`', '', d\)\}\"\\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "4s/^/LDFLAGS_remove_dunfell = \"\$\{@bb\.utils\.contains\('DISTRO_FEATURES', 'safec', '-lsafec-3\.5', '', d\)\}\"\\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "5s/^/LDFLAGS_append = \"\$\{@bb\.utils\.contains\('DISTRO_FEATURES', 'safec dunfell', ' -lsafec-3\.5\.1 ', '', d\)\}\"\\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "6s/^/CFLAGS_append = \" \$\{@bb\.utils\.contains\('DISTRO_FEATURES', 'safec', '', ' -DSAFEC_DUMMY_API', d\)\}\"\\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "7s/^/CFLAGS_append = \" \\\\ \\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "8s/^/-I\$\{STAGING_INCDIR\} \\\\ \\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "9s/^/-I\$\{STAGING_INCDIR\}\/dbus-1\.0 \\\\ \\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "10s/^/-I\$\{STAGING_LIBDIR\}\/dbus-1\.0\/include \\\\ \\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "11s/^/-I\$\{STAGING_INCDIR\}\/ccsp\\\\ \\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        sed -i "12s/^/\"\\n/" meta-ipq/recipes-ccsp/ccsp/ccsp-eth-agent.bbappend
        chmod +x $WORKSPACE/components/ccsp-eth-agent-fixes.sh
        bash $WORKSPACE/components/ccsp-eth-agent-fixes.sh
    fi
}
dbus-patch() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ -d "meta-ipq/recipes-ccsp/util/dbus" ] && grep -q "01-dbus-ccsp-apis" "meta-ipq/recipes-ccsp/util/utopia.bbappend"; then
        echo "dbus patch is already applied"
    else
        cp $WORKSPACE/$ONEFW_TOPDIR/meta-mng/recipes-misc/dbus/dbus/01-dbus-ccsp-apis-1.12.24.patch $WORKSPACE/$ONEFW_TOPDIR/meta-ipq/recipes-ccspinternal/dbus/dbus/
        sed -i "/FILESEXTRAPATHS_prepend/d" meta-mng/recipes-misc/dbus/dbus_%.bbappend
        sed -i "/SRC_URI_append_class-target/d" meta-mng/recipes-misc/dbus/dbus_%.bbappend
        sed -i '/SRC_URI_append_broadband/d' meta-ipq/recipes-ccspinternal/dbus/dbus_%.bbappend
        sed -i "3s/^/SRC_URI_append_broadband = \" file\:\/\/01-dbus-ccsp-apis-\$\{PV\}\.patch \\\\ \\n/" meta-ipq/recipes-ccspinternal/dbus/dbus_%.bbappend
    fi
}
systemd_fix() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i 's/INIT_MANAGER ?= "mdev-busybox"/INIT_MANAGER ?= "systemd"/g' meta-mng/conf/distro/mng.conf
    echo '
DISTRO_FEATURES_append = " parodus"
DISTRO_FEATURES_append = " webui_jst"
DISTRO_FEATURES_append = " rdkb_wan_manager"
DISTRO_FEATURES_append = " easymesh-controller"
DISTRO_FEATURES_append = " rdkb_xdsl_ppp_manager"
DISTRO_FEATURES_append = " telemetry"
DISTRO_FEATURES_append = " crashupload"
DISTRO_FEATURES_append = " fwupgrade_manager"
PREFERRED_VERSION_samba_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '4.10.18', '3.6.25', d)}"
PREFERRED_VERSION_gnutls_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '3.6.14', '3.3.30', d)}"
PREFERRED_VERSION_nettle_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '3.5.1', '2.7.1', d)}"
PREFERRED_VERSION_gmp_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '6.2.0', '4.2.1', d)}"
PREFERRED_VERSION_wireless-tools_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '29', '30.pre9', d)}"
PREFERRED_VERSION_nghttp2_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '1.40.0', '1.31.1', d)}"
PREFERRED_VERSION_iw_dunfell = "${@bb.utils.contains('DISTRO_FEATURES', '', '5.16', '4.7', d)}"
DISTRO_FEATURES_remove = " bluetooth bluez5 "
QEMU_TARGETS += " aarch64 " ' >>meta-mng/conf/distro/mng.conf
    echo '
include recipes-core/images/ipq-pkgs.inc
IMAGE_INSTALL += " \
        kernel-modules \
        ${IPQ_BASE_PKGS} \
        ${NETWORK_PKGS} \
        ${UTILS} \
        board-default \
        "
NSS_ipq95xx_64 = "${SSDK_NOHNAT_PKGS} \
                  ${NSS_PKGS} \
                  ${IPQ95XX_NSS_PKGS} \
                 "
WIFI_ipq95xx_64 = "${WIFI_PKGS}"
IPQ_BASE_PKGS = "strace e2fsprogs kexec-tools u-boot-fw-utils  mtd mtd-utils mtd-utils-ubifs  wififw-mount qca-qmi-framework qca-diag ipq-boot procps watchdog-keepalive mcproxy qcawifi-scripts ${SYSUPGRADE} button-hotplug datarmnet tcpdump wolfssl initoverlay util-linux"
NETWORK_PKGS = "ethtool iproute2 iproute2-tc iptables open-iw dhcp-server wireless-tools mcproxy nat46 ntp"
UTILS = "perf pm-utils file rng-tools ppp ppp-oe pdt"
SYSUPGRADE_ipq95xx_64 = "sysupgrade-helper sysupgrade"
SSDK_NOHNAT_PKGS ="qca-ssdk-nohnat qca-ssdk-shell"
NSS_PKGS += " \
            qca-nss-dp \
            qca-nss-ecm \
            "
QCA_NSS_PPE = "qca-nss-ppe qca-nss-ppe-vp qca-nss-ppe-ds"
QCA_NSS_PPE_TUN = "qca-nss-ppe-tun qca-nss-ppe-tunipip6 qca-nss-ppe-mapt qca-nss-ppe-gretap qca-nss-ppe-vxlanmgr"
IPQ95XX_NSS_PKGS += "${QCA_NSS_PPE} ${QCA_NSS_PPE_TUN} qca-nss-sfe strongswan qca-nss-eip qca-nss-fw-eip-al"
MCS_PKGS = "qca-mcs-lkm qca-mcs-app"
WIFI_PKGS = "qca-hostapd  qca-wpasupplicant qca-cfg80211 qca-cfg80211tool qca-cnss wififw-mount qca-wifi-files qca-wifi open-iw wireless-tools hostapd-scripts wpasupplicant-scripts ath6kl-utils qca-ftm qca-cnssdiag qca-cnss-daemon athtestcmd "
IMAGE_INSTALL_append_ipq40xx += "${SSDK_HNAT_PKGS} \
                                 ${RFS_PKGS} \
                                 ${QCA_ECM} \
                                 ${QCA_EDMA} \
                                 ${MCS_PKGS} \
                                 ${WIFI_PKGS} \
                                "
IMAGE_INSTALL_append_ipq807x += "${SSDK_NOHNAT_PKGS} \
                                 ${QCA_ECM} \
                                 ${QCA_EDMA} \
                                "
IMAGE_INSTALL_append_ipq807x-64 += "${SSDK_NOHNAT_PKGS} \
                                   "
NSS_ipq95xx = "${SSDK_NOHNAT_PKGS} \
               ${NSS_PKGS} \
               ${IPQ95XX_NSS_PKGS} \
                "
NSS_ipq807x_64 = "${SSDK_NOHNAT_PKGS} \
                  ${NSS_PKGS} \
                  ${IPQ807X_NSS_PKGS} \
                 "
NSS_ipq807x = "${SSDK_NOHNAT_PKGS} \
               ${NSS_PKGS} \
               ${IPQ807X_NSS_PKGS} \
              "
IMAGE_INSTALL += " \
                ${NSS} \
                ${MCS_PKGS} \
                "
WIFI_ipq95xx = "${WIFI_PKGS}"
IMAGE_INSTALL += "${WIFI}"
IMAGE_INSTALL += "rdk-fwupgrade-manager"
IMAGE_INSTALL += "telemetry"
EXTRA_IMAGEDEPENDS += " \
                       memtester \
                       dosfstools \
                       "
IMAGE_INSTALL_remove = " \
                        ${EXTRA_IMAGEDEPENDS} \
                        "
    ' >>meta-mng/recipes-core/images/ofw.bb
}
qrdk_packages_fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    echo '
TARGET_CFLAGS += " -Wno-error=unused-variable -Wno-error=unused-but-set-variable -Wno-error=unused-result "
	' >>meta-ipq/recipes-qcawifi/qca-cnss-daemon/qca-cnss-daemon.bb
    echo '
TARGET_CFLAGS += " -Wno-error=unused-variable -Wno-error=unused-but-set-variable -Wno-error=unused-result "
	' >>meta-ipq/recipes-hyfi/libhyficommon/libhyficommon.bb
    echo '
TARGET_CFLAGS += " -Wno-error=unused-variable -Wno-error=unused-but-set-variable -Wno-error=unused-result "
        ' >>meta-ipq/recipes-mcs/qca-mcs-app/qca-mcs-app.bb
}
ccsp-wifi-agent-fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i '/dpp-hostapd-update.sh/d' meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent.bbappend
    sed -i '/addtask/d' meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent.bbappend
    sed -i '/file:\/\/0/d' meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent.bbappend
    if grep -q "wifi_setRadioExcludeDfs" "rdkb/devices/ipq/hal/hal-qcawifi/source/hal-qcawifi/wifi_hal.c"; then
        echo "patch is already applied in ccsp_wifi_agent"
    else
        chmod +x $WORKSPACE/components/ccsp-wifi-agent-fixes.sh
        bash $WORKSPACE/components/ccsp-wifi-agent-fixes.sh
    fi
    if [ ! -f meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent/ccsp-wifi-agent-itr.patch ]; then
        cat <<EOF >meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent/ccsp-wifi-agent-itr.patch
diff --git a/source/TR-181/sbapi/wifi_monitor.c b/source/TR-181/sbapi/wifi_monitor.c
index c57e9c2..891ca78 100644
--- a/source/TR-181/sbapi/wifi_monitor.c
+++ b/source/TR-181/sbapi/wifi_monitor.c
@@ -867,7 +867,8 @@ int upload_client_telemetry_data(void *arg)
             // check if we should enable of disable detailed client stats collection on XB3
-            UINT radioIndex = 0; 
+            UINT radioIndex = 0;
+	    unsigned int itr = 0;
             for (itr = 0; itr < (UINT)getTotalNumberVAPs(); itr++) 
             {
                 if (stflag[itr] == 1) 
EOF
        cat <<EOF >meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent/ccsp-wifi-agent-puma6-atom.patch
Index: git/source/TR-181/sbapi/cosa_wifi_apis.c
===================================================================
--- a/source/TR-181/sbapi/cosa_wifi_apis.c
+++ b/source/TR-181/sbapi/cosa_wifi_apis.c
@@ -10683,7 +10683,7 @@ ANSC_STATUS CosaDmlWiFiSetForceDisableWi
     if (CCSP_SUCCESS == PSM_Set_Record_Value2(bus_handle,
             g_Subsystem, WiFiForceDisableWiFiRadio, ccsp_string, recValue))
     {
-#if !defined(_PUMA6_ATOM_)
+#if defined(_PUMA6_ATOM_)
         wifi_apply();
         if(bValue) {
             CcspWifiTrace((\"RDK_LOG_WARN, WIFI_FORCE_DISABLE_CHANGED_TO_TRUE\\n\"));
EOF
        echo "
SRC_URI_append = \"file://ccsp-wifi-agent-itr.patch \\
	file://ccsp-wifi-agent-puma6-atom.patch \\
\"
       " >>meta-ipq/recipes-ccsp/ccsp/ccsp-wifi-agent.bbappend
    else
        echo "ccsp wifi agent patch already applied"
    fi
}
gw-prov-eth-wan-fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    echo '
IMAGE_INSTALL += "ccsp-gwprovapp-ethwan"
IMAGE_INSTALL += "hal-mso-mgmt-generic"
    ' >>meta-mng/recipes-core/images/ofw.bb
    echo '
DEPENDS += "utopia telemetry hal-mso-mgmt-generic" 
RDEPENDS_${PN} += " hal-mso-mgmt-generic "
    ' >>meta-ipq/recipes-ccsp/ccsp/ccsp-gwprovapp-ethwan.bbappend
    sed -i -e 's/meta-cmf-ipq/meta-ipq/' meta-ipq/recipes-ccsp/ccsp/ccsp-gwprovapp-ethwan.bbappend
    sed -i -e 's/addtask/\#addtask/g' meta-ipq/recipes-ccsp/ccsp/ccsp-gwprovapp-ethwan.bbappend
}
dnsmasq_meta_rdk_ext() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    git clone -b rdkb-2022q4-dunfell https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext
    cd meta-rdk-ext
    git sparse-checkout init --cone
    git sparse-checkout set recipes-support/dnsmasq
    cd $WORKSPACE/$ONEFW_TOPDIR
    cp meta-rdk-ext/recipes-support/dnsmasq/dnsmasq/dnsmasqLauncher.sh meta-ipq/recipes-support/dnsmasq/file/
    cp meta-rdk-ext/recipes-support/dnsmasq/dnsmasq/dnsmasq.service meta-ipq/recipes-support/dnsmasq/file
    cd meta-ipq/recipes-support/dnsmasq/file
    patch -p0 <dhcpfixup.patch
    cd $WORKSPACE/$ONEFW_TOPDIR
    cat <<EOL >meta-ipq/recipes-support/dnsmasq/dnsmasq_%.bbappend
FILESEXTRAPATHS_append := "\${THISDIR}/file:"
SRC_URI += "file://dnsmasqLauncher.sh"
FILES_\${PN}_append = " \${base_libdir}/rdk/* "
do_install_append() {
    install -d \${D}\${base_libdir}/rdk
    install -m 0644 \${WORKDIR}/dnsmasq.service \${D}\${systemd_unitdir}/system
    sed -i -- 's/#resolv-file=/resolv-file="\/etc\/resolv.dnsmasq"/g' \${D}/etc/dnsmasq.conf
    sed -i -- 's/#user=/user=root/g' \${D}/etc/dnsmasq.conf
    sed -i -- 's/#dhcp-leasefile=\/var\/lib\/misc\/dnsmasq.leases/dhcp-leasefile=\/tmp\/dnsmasq.leases/g' \${D}/etc/dnsmasq.conf
    install -m 0755 \${S}/../dnsmasqLauncher.sh \${D}\${base_libdir}/rdk
}
RDEPENDS_\${PN} += "busybox"
SRC_URI += "file://dnsmasq.service"
do_install_append_hybrid() {
    install -D -m 0644 \${WORKDIR}/dns.conf \${D}\${systemd_unitdir}/system/dnsmasq.service.d/dns.conf
}
do_install_append_client() {
    install -D -m 0644 \${WORKDIR}/dns.conf \${D}\${systemd_unitdir}/system/dnsmasq.service.d/dns.conf
}
FILES_\${PN}_append_hybrid += " \${systemd_unitdir}/system/dnsmasq.service.d/dns.conf"
FILES_\${PN}_append_client += " \${systemd_unitdir}/system/dnsmasq.service.d/dns.conf"
EOL
}
manual-ipconfig-fixes() {
   [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if [ ! -f meta-ipq/recipes-support/manual-ipconfig/manual-ipconfig.service ]; then
	    chmod +x $WORKSPACE/components/manual-ipconfig-fixes.sh
	    bash $WORKSPACE/components/manual-ipconfig-fixes.sh
    else
	    echo "manual-ipconfig patch is already applied"
    fi
}
ccsp-common-library_fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if grep -q "GwProvCheck.sh" "meta-ipq/recipes-ccsp/ccsp/ccsp-common-library.bbappend"; then
        echo "Patch is already applied in ccsp_common_library"
    else
        sed -i '190i\   install -m 777 ${S}/systemd_units/scripts/GwProvCheck.sh ${D}/usr/ccsp/pam/GwProvCheck.sh' meta-ipq/recipes-ccsp/ccsp/ccsp-common-library.bbappend
    fi
}
meta-python2-fixes() {
   [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
   chmod +x $WORKSPACE/components/meta-python2-fix.sh
   bash $WORKSPACE/components/meta-python2-fix.sh
}
ccsp-psm-fixes() {
   [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
   cp $WORKSPACE/components/bbhm_patch.sh meta-ipq/recipes-ccsp/ccsp/ccsp-psm
   echo "
SRC_URI += \"file://bbhm_patch.sh\"
do_install_append() {
        install -d \${D}/usr/ccsp/psm
        install -m 755 \${WORKDIR}/bbhm_patch.sh \${D}/usr/ccsp/psm/bbhm_patch.sh
}
" >> meta-ipq/recipes-ccsp/ccsp/ccsp-psm.bbappend
}
qrdk_recipe_fixes() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i -e 's/RDEPENDS_kernel-base/RDEPENDS_${KERNEL_PACKAGE_NAME}-base/' meta-ipq/conf/machine/include/ipq-base.inc
    [ -e meta-ipq/recipes-ccspinternal/dbus/dbus/02-dbus-ccsp-apis-1.12.24.patch ] && echo "dbus already fixed"
    cd meta-ipq/recipes-ccspinternal/dbus/dbus
    cp 02-dbus-ccsp-apis-1.12.16.patch 02-dbus-ccsp-apis-1.12.24.patch
    cd -
    sed -i -e "s/meta-cmf-ipq/meta-ipq/" meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot.bbappend
    ccsp_hotspot_patch
    sed -i -e "s/meta-cmf-ipq/meta-ipq/" meta-ipq/recipes-ccsp/ccsp/ccsp-cr.bbappend
    sed -i -e "s/\(qdecoder.git;protocol=https\)/\1;branch=main/" meta-mng/recipes-misc/qdecoder/qdecoder_12.0.8.bb
    sed -i -e "s/\(^.*install.*rbus_rdkb.conf.*$\)/#\1/" meta-mng/recipes-common/rbus/rbus.bb
    sed -i -e 's/meta-cmf-ipq/meta-ipq/' meta-ipq/recipes-common/lighttpd/lighttpd_%.bbappend
    sed -i -e 's/\(install .*getaccountid.sh.*\)/#\1/' meta-ipq/recipes-ccsp/ccsp/sysint-broadband.bbappend
    sed -i -e 's/\(install .*sysint.utils.sh.*\)/#\1/' meta-ipq/recipes-ccsp/ccsp/sysint-broadband.bbappend
    sed -i -e 's/\(install .*getpartnerid.sh.*\)/#\1/' meta-ipq/recipes-ccsp/ccsp/sysint-broadband.bbappend
    sed -i -e 's/\(install .*meta-cmf-ipq.*\)/#\1/' meta-ipq/recipes-ccsp/ccsp/sysint-broadband.bbappend
    sed -i -e 's/\(install.*bbhm_patch.sh.*\)/#\1/' meta-ipq/recipes-ccsp/ccsp/ccsp-psm.bbappend
    ccsp_misc_patch
    hal_ethsw_generic_fixes
    qca_wifi_fixes
    hal_platform_generic_fixes
    halinterface_fix
    ccsp-lm-lite_patch
    ccsp_cr_fix
    ccsp_p_and_m_patch
    rdk_wanmanager_patch
    utopia_patch
    ccsp-eth-agent-patch
    dbus-patch
    systemd_fix
    qrdk_packages_fixes
    ccsp-wifi-agent-fixes
    gw-prov-eth-wan-fixes
    dnsmasq_meta_rdk_ext
    ccsp-common-library_fixes
    manual-ipconfig-fixes
    meta-python2-fixes
    ccsp-psm-fixes
}
fix_qrdk_for_onefw() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    if grep 'BBMASK' build-$MACHINE_NAME/conf/local.conf; then
        echo 'Already BBMASK added' && return
    fi
    sed -i -e '$aBBMASK += "meta-ipq/recipes-connectivity/dibbler/dibbler_%.bbappend"' build-$MACHINE_NAME/conf/local.conf
    sed -i -e '$aBBMASK += "meta-ipq/recipes-ccsp/ccsp/ccsp-hotspot.bbappend"' build-$MACHINE_NAME/conf/local.conf
    sed -i -e '$aBBMASK += "meta-ipq/recipes-ccsp/ccsp/rdk-fwupgrade-manager.bbappend"' build-$MACHINE_NAME/conf/local.conf
    sed -i -e '$aBBMASK += "meta-ipq/recipes-ccsp/ccsp/ccsp-tr069-pa.bbappend"' build-$MACHINE_NAME/conf/local.conf
    sed -i -e '$aBBMASK += "meta-ipq/recipes-core/busybox/busybox_%.bbappend"' build-$MACHINE_NAME/conf/local.conf
    sed -i -e '$aBBMASK += "meta-ipq/recipes-core/dropbear/dropbear_%.bbappend"' build-$MACHINE_NAME/conf/local.conf
    sed -i -e '$aRDK_GIT_PROTOCOL ?= "https"' meta-mng/conf/distro/include/mng-versions-local.inc
    sed -i -e '$aCMF_GIT_ROOT ?= "git://code.rdkcentral.com/r"' meta-mng/conf/distro/include/mng-versions-local.inc
    sed -i -e '$aCMF_GIT_PROTOCOL ?= "https"' meta-mng/conf/distro/include/mng-versions-local.inc
    sed -i -e '$aCMF_GIT_BRANCH ?= "rdk-next"' meta-mng/conf/distro/include/mng-versions-local.inc
    sed -i -e '$aCCSP_GIT_BRANCH ?= "rdkb-2022q4-dunfell"' meta-mng/conf/distro/include/mng-versions-local.inc
}
setup_onefw4ipq() {
    [ ! ${PWD##*/} == $ONEFW_TOPDIR ] && cd $WORKSPACE/$ONEFW_TOPDIR
    sed -i -e '$aCCSP_CONFIG_ARCH = "--with-ccsp-arch=arm"' meta-ipq/conf/machine/ipq95xx_64.conf
    sed -i -e '$aCCSP_CONFIG_PLATFORM = "--with-ccsp-platform=bcm"' meta-ipq/conf/machine/ipq95xx_64.conf
    sed -i -e '$aCCSP_CFLAGS_MACHINE = "-D_COSA_INTEL_USG_ARM_ -D_COSA_BCM_ARM_ -D_PLATFORM_IPQ_ "' meta-ipq/conf/machine/ipq95xx_64.conf
    MACHINE=$MACHINE_NAME source ./meta-mng/setup-environment
    fix_qrdk_for_onefw
    qrdk_recipe_fixes
}
check_build_machine() {
    if cat /etc/issue | cut -f2 -d" " | grep "22.04"; then
        echo "Build with this OS is Verified"
    else
        echo "Build with this OS is not Verified"
        exit 0
    fi
}
check_build_machine
if [ ! -d $WORKSPACE/$ONEFW_TOPDIR/build-$MACHINE_NAME ]; then
    setup_chipcode
    repo_sync_qrdk
    repo_sync_onefw
    setup_qrdk_downloads $ONEFW_TOPDIR
    extract_qrdk_from_chipcode $ONEFW_TOPDIR
    change_qrdk_pkg_rev $ONEFW_TOPDIR
    collate_qrdk_to_onefw
    setup_onefw4ipq
else
    MACHINE=$MACHINE_NAME source ./meta-mng/setup-environment
fi
bitbake ofw
