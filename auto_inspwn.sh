high="\033[1m"
reset="\033[0m"

is_def=1

function get_yesno(){   
    #  args1==输出的消息
    #  args2==默认值  0==yes  1==no
    #  args3==是否默认 0==yes 1==no
    poss=("yes" "no")
    litt_poss=("y" "n")
    info=$1
    d_v=$2

    echo -n -e $info' ['$high${poss[$d_v]}$reset'/'${poss[$d_v^1]}']: '

    if [[ $is_def == 0 ]]
    then
        echo ${poss[$d_v]}
        return $d_v
    fi
    
    read yes_no
    if [[ $yes_no == ${poss[$d_v^1]} || $yes_no == ${litt_poss[$d_v^1]} ]]; then
        return $(($d_v^1))
    fi
    return $d_v
}

function info(){
    echo -e "["$high$1$reset"]"$2
}

function change_apt_source(){
    info "info" "change apt source start"
    ubuntu_lsb=$(lsb_release -a 2>/dev/null|\
         awk -F " " '{\
            if ( $1    ~ /Codename/ ){\
                print $2\
             }\
           }')

    method="https"
    iptype="4"

    get_yesno "是否使用ipv4协议源" 0 1
    if [[ $? == 1 ]];then
        iptype="6"
    fi

    get_yesno "是否使用https协议源" 0 1
    if [[ $? == 1 ]]; then
        method="http"
    fi

    echo -e "已将"$high"/etc/apt/sources.list"$reset"备份到"$high"/etc/apt/sources.list.back"$reset    
    cp /etc/apt/sources.list /etc/apt/sources.list.back

    wget  "https://mirrors.ustc.edu.cn/repogen/conf/ubuntu-"$method"-"$iptype"-"$ubuntu_lsb -O /etc/apt/sources.list -T 4

    if [[ $? != 0 ]]; then
        info "error"  "获取apt源超时，请检查网络配置"
        mv /etc/apt/sources.list.back /etc/apt/sources.list
        exit -1
    fi
    info "success"  "获取apt源已完成"

    apt-get update 
    if [[ $? == 0 ]];then
        info "success" "更新apt源已完成"
    else
        info "error" "更新源失败，请检查配置"
        mv /etc/apt/sources.list.back /etc/apt/sources.list
        exit -1
    fi
    info "success" "change apt source success"
}

function python_install(){
    info "info" "python install start"
    py2_install=1
    py3_install=1
    if [[ $1 == 2 ]]; then
        py3_install=0
    elif [[ $1 == 3 ]]; then
        py2_install=0
    fi

    mkdir ./pycache
    if [[ $py2_install == 1 ]]; then
        python2 --version 2>/dev/null
        if [[ $? == 0 ]]; then
            info "wrong" "python2已被安装，无需重新安装"
        else
            apt install python2 -y
            if [[ $? != 0 ]]; then
                get_yesno "搜索不到python2安装包，是否尝试使用python安装包" 0 1
                if [[ $? == 0 ]]; then
                    apt install python -y
                fi
            fi
        fi
        
        pip2 --version 2>/dev/null
        if [[ $? == 0 ]]; then
            info "wrong" "python2的pip已被安装，无需重新安装"
        else
            wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O ./pycache/py2get-pip.py -T 4
            if [[ $? != 0 ]]; then
                info "error" "获取get-pip脚本超时，请检查网络配置"
                exit -1
            fi
            python2 ./pycache/py2get-pip.py
            python2 -m pip install --upgrade pip
            cp /usr/local/bin/pip /usr/local/bin/pip2 
        fi

    fi

    if [[ $py3_install == 1 ]]; then
        python3 --version 2>/dev/null
        if [[ $? == 0 ]]; then
            info "wrong" "python3已被安装，无需重新安装"
        else
            apt install python3 -y
        fi
        
        pip3 --version  2>/dev/null
        if [[ $? == 0 ]]; then
            info "wrong" "python3的pip已被安装，无需重新安装"
        else
            wget https://bootstrap.pypa.io/pip/3.6/get-pip.py -O ./pycache/py3get-pip.py -T 4
            if [[ $? != 0 ]]; then
                info "error" "获取get-pip脚本超时，请检查网络配置"
                exit -1
            fi
            py3_ver=$(python3 --version| awk -F " " '{ print $2 }')
            py3_ver=${py3_ver%.*}
            apt install "python"$py3_ver"-distutils" -y
            python3 ./pycache/py3get-pip.py
            python3 -m pip install --upgrade pip
            cp /usr/local/bin/pip /usr/local/bin/pip3 
        fi
    fi
    
    if [[ $py3_install == 1 && $py2_install == 1 ]]; then
        pyt_v=$(python2 -c "import sys;print(sys.executable)")
        pip_v=2
        get_yesno "是否将python2设置为默认的python" 0 1
    
        if [[ $? == 1 ]];then
            pyt_v=$(python3 -c "import sys;print(sys.executable)")
        pip_v=3
        fi
        python_path=${pyt_v%/*}"/python"

        rm -rf $python_path
        ln $pyt_v $python_path
        cp /usr/local/bin/pip$pip_v /usr/local/bin/pip
        if [[ $? != 0 ]];then
            info "error" "创建链接失败"
            exit -1
        fi
    fi
    rm -rf pycache
    info "info" "python install success"
}

function pwntools_install(){
    info "info" "pwntools install start"
    apt install git libssl-dev libffi-dev build-essential python3-dev -y
    apt install python2-dev -y
    if [[ $? != 0 ]]; then
        get_yesno "搜索不到python2安装包，是否尝试使用python安装包" 0 1
        if [[ $? == 0 ]]; then
            apt install python-dev -y
        fi
    fi
    
    python2 --version 2>/dev/null
    while [[ $? != 0 ]]
    do
        get_yesno "python2不存在，是否安装python2" 0 1
        if [[ $? == 0 ]]; then
            python_install 2
        else
            break
        fi
        python2 --version 2>/dev/null
    done
    
    python2 --version 2>/dev/null
    if [[ $? == 0  ]] ; then
        python2 -c "import pwn" 2>/dev/null
        
        if [[ $? == 0 ]]; then
            python2 -m pip install -U pwntools
        else
            python2 -c "import pwn" 2>/dev/null
            while [[ $? != 0 ]]
            do
                python2 -m pip install -U pip
                pip2 install packaging==16.6
                pip2 install -U packaging==16.6
                pip2 install pwntools
                python2 -c "import pwn" 2>/dev/null
                if [[ $? != 0 ]] ; then
                    get_yesno "python2安装pwntools失败，是否跳过安装" 0 1
                fi
            done
        fi
    fi
    
    python3 --version 2>/dev/null
    while [[ $? != 0 ]]
    do
        get_yesno "python3不存在，是否安装python3" 0 1
        if [[ $? == 0 ]]; then
            python_install 3
        else 
            break
        fi
        python3 --version 2>/dev/null
    done
    
    python3 --version 2>/dev/null
    if [[ $? == 0 ]]; then
        python3 -c "import pwn" 2>/dev/null
        if [[ $? == 0 ]]; then
            python3 -m pip install -U pwntools
        else
            python3 -m pip install -U pip
            python3 -c "import pwn" 2>/dev/null
            while [[ $? != 0 ]]
            do
                pip3 install packaging==16.6
                pip3 install -U packaging==16.6
                pip3 install pwntools
                python3 -c "import pwn" 2>/dev/null
                if [[ $? != 0 ]] ; then
                    get_yesno "python3安装pwntools失败，是否跳过安装" 0 1
                fi
            done
        fi
    fi
    
    get_yesno "需要在每次导入pwntools时，进行更新检测吗" 1 1
    if [[ $? != 0 ]]; then
        echo -e "[update]\ninterval=never" > /root/.pwn.conf
    else
    rm -rf /root/.pwn.conf
    fi
    info "info" "pwntools install success"
}

function libcsearch_install(){
    info "info" "LibcSearcher install start"
    python3 -c "import LibcSearcher" 2>/dev/null
    if [[ $? == 0 ]] ; then
        info "wrong" "python3的LibcSearcher已安装，无需重新安装"
    else
        python3 -m pip install -U pip 2>/dev/null
        while [[ $? != 0 ]]
        do
            get_yesno "python3不存在，是否安装python3" 0 1
            if [[ $? == 0 ]]; then
                python_install 3
            else
                break
            fi
            python3 -m pip install -U pip 2>/dev/null
        done
        
        git_libc=0
        python3 -m pip install -U pip 2>/dev/null
        if [[ $? == 0 ]]; then
            get_yesno "是否安装新版LibcSearcher" 0 1
            if [[ $? == 0 ]] ; then
                python3 -m pip install LibcSearcher 
                info "info" "如果想要在本地搭建用于查询libc的服务器，可以参考 https://bbs.pediy.com/thread-263302.htm"
            else
                python3 -c "import LibcSearcher" 2>/dev/null
                while [[ $? != 0 ]]
                do
                    git --version 2>/dev/null >/dev/null
                    if [[ $? != 0 ]]; then
                        apt install git -y
                    fi
                    git clone https://github.com/lieanu/LibcSearcher
                    if [[ $? != 0 ]];then
                        info "error" "获取libcsearch失败，请检查网络"
                        exit -1
                    fi
                    git_libc=1
                    py3_mod_path=$(python3 -c "import pip;print(pip.__file__)")
                    py3_mod_path=${py3_mod_path%/*/*}
                    cd LibcSearcher 
                    cp LibcSearcher.py libc-database $py3_mod_path -r
                    cd ..
                    python3 -c "import LibcSearcher" 2>/dev/null
                    if [[ $? != 0 ]] ; then
                        get_yesno "python3安装LibcSearcher失败,是否跳过安装" 0 1
                    fi
                done
            fi
        fi
    fi
    
    python2 -c "import LibcSearcher" 2>/dev/null
    if [[ $? == 0 ]] ; then
        info "wrong" "python2的LibcSearcher已安装，无需重新安装"
    else
        python2 -m pip install -U pip 2>/dev/null  >/dev/null
        while [[ $? != 0 ]]
        do
            get_yesno "python2或pip2不存在，是否尝试安装" 0 1
            if [[ $? == 0 ]]; then
                python_install 2
            else
                break
            fi
            python2 -m pip install -U pip 2>/dev/null >/dev/null
        done
        
        python2 -m pip install -U pip 2>/dev/null >/dev/null 
        if  [[ $? == 0 ]]  ; then
            python2 -c "import LibcSearcher" 2>/dev/null 
            while [[ $? != 0 ]]
            do
                git --version 2>/dev/null >/dev/null 
                if [[ $? != 0 ]]; then
                    apt install git -y
                fi
                if [[ $git_libc != 1 ]]; then
                    git clone https://github.com/lieanu/LibcSearcher 
                    if [[ $? != 0 ]];then
                        info "error" "获取libcsearch失败，请检查网络"
                        exit -1
                    fi
                else
                    info "success" "在python3安装LibcSearcher时，已经获取了LibcSearcher"
                fi
        
                py2_mod_path=$(python2 -c "import pip;print(pip.__file__)")
                py2_mod_path=${py2_mod_path%/*/*}
                cd LibcSearcher 
                cp LibcSearcher.py libc-database $py2_mod_path -r
                cd ..
                python2 -c "import LibcSearcher" 2>/dev/null
                if [[ $? != 0 ]] ; then
                    get_yesno "python2安装LibcSearcher失败,是否跳过安装" 0  1
                fi
            done
        fi
    fi
    info "info" "LibcSearcher install success"
}

function gdb_install(){
    info "info" "gdb install start"
    gdb --version >/dev/null 2>/dev/null
    local peda=""
    local peda_arm=""
    local pwndbg=""
    local peda_intel=""
    local gef=""
    local is_err=0
    if [[ $? != 0 ]];then
        apt install gdb -y
    fi
    while [[ 1 = 1 ]]
    do
        git --version >/dev/null 2>/dev/null
        if [[ $? != 0 ]]; then
            apt install git -y
        fi
        mv ~/.gdbinit ~/.gdbinit.back 2>/dev/null
        if [[ -e ~/peda ]]; then
            info "wrong" "peda已安装，不需要重复安装"
            peda="define init_peda\n source ~/peda/peda.py\n end\n"
            echo -e "#!/bin/sh\nexec gdb -q -ex init_peda \$@" > /bin/peda
        else
            git clone https://github.com/longld/peda ~/peda
            if [[ $? == 0 ]] ; then
                peda="define init_peda\n source ~/peda/peda.py\n end\n"
                echo -e "#!/bin/sh\nexec gdb -q -ex init_peda \$@" > /bin/peda
            else
                info "error" 利用git获取peda失败，请检查网络配置
                is_err=1
                break
            fi
        fi
        
        if [[ -e ~/peda-arm ]]; then
            info "wrong" "peda-arm已安装，不需要重复安装"
            peda_arm="define init_peda-arm\n source ~/peda-arm/peda-arm.py\n end\n"
            echo -e "#!/bin/sh\nexec gdb -q -ex init_peda-arm \$@" > /bin/peda-arm
    
            peda_intel="define init_peda-intel\n source ~/peda-arm/peda-intel.py\n end\n"
            echo -e "#!/bin/sh\nexec gdb -q -ex init_peda-intel \$@" > /bin/peda-intel
        else
            git clone https://github.com/alset0326/peda-arm ~/peda-arm
            if [[ $? == 0 ]] ; then
                peda_arm="define init_peda-arm\n source ~/peda-arm/peda-arm.py\n end\n"
                echo -e "#!/bin/sh\nexec gdb -q -ex init_peda-arm \$@" > /bin/peda-arm
    
                peda_intel="define init_peda-intel\n source ~/peda-arm/peda-intel.py\n end\n"
                echo -e "#!/bin/sh\nexec gdb -q -ex init_peda-intel \$@" > /bin/peda-intel
            else
                info "error" 利用git获取peda-arm失败，请检查网络配置
                is_err=1
                break
            fi
        fi
        
        if [[ -e ~/pwndbg ]]; then
            info "wrong" "pwndbg已安装，不需要重复安装"
            pwndbg="define init_pwndbg\n source ~/pwndbg/gdbinit.py\n end\n"
            echo -e "#!/bin/sh\nexec gdb -q  -ex init_pwndbg \$@" > /bin/pwndbg
        else
            git clone https://github.com/pwndbg/pwndbg ~/pwndbg
            if [[ $? == 0 ]] ; then
                curr_dir=$(pwd)
                cd ~/pwndbg
                ./setup.sh
                pwndbg="define init_pwndbg\n source ~/pwndbg/gdbinit.py\n end\n"
                echo -e "#!/bin/sh\nexec gdb -q -ex init_pwndbg \$@ " > /bin/pwndbg
            else
                info "error" 利用git获取pwndbg失败，请检查网络配置
                is_err=1
                break
            fi
        fi
        if [[ -e ~/gef ]]; then
            info "wrong" "gef已安装，不需要重复安装"
            gef="define init_gef\n source ~/gef/gef.py\n end\n"
            echo -e "#!/bin/sh\nexec gdb -q -ex init_gef \$@" > /bin/gef
        else
            git clone https://github.com/hugsy/gef ~/gef
            if [[ $? == 0 ]] ; then
                gef="define init_gef\n source ~/gef/gef.py\n end\n"
                echo -e "#!/bin/sh\nexec gdb -q -ex init_gef \$@" > /bin/gef
            else
                info "error" 利用git获取gef失败，请检查网络配置
                is_err=1
                break
            fi
        fi
        break
    done    
    rm -rf ~/.gdbinit 2>/dev/null >/dev/null
    chmod +x /bin/peda 2>/dev/null
    chmod +x /bin/peda-arm 2>/dev/null
    chmod +x /bin/peda-intel 2>/dev/null
    chmod +x /bin/gef 2>/dev/null
    chmod +x /bin/pwndbg 2>/dev/null
    if [[ $is_err == 0 ]]; then
        get_yesno "在执行gdb命令时是否使用默认gdb" 1 1
        if [[ $? != 0 ]]; then
            echo -n -e "请输入默认执行gdb命令时，使用的插件 ["$high"pwndbg"$reset"/peda/peda-arm/peda-intel/gef]"
            if [[ $is_def == 0 ]]; then 
                gdb_var="pwndbg"   
            else
                read gdb_var
                if [[ -z $gdb_var ]]; then
                    gdb_var="pwndbg"
                fi
            fi
    
            case $gdb_var in
                peda) echo -e "source ~/peda/peda.py\n" > ~/.gdbinit ;;
                peda-arm) echo -e "source ~/peda-arm/peda-arm.py\n" > ~/.gdbinit ;;
                peda-intel) echo -e "source ~/peda-arm/peda-intel.py\n"> ~/.gdbinit ;;
                pwndbg) echo -e "source ~/pwndbg/gdbinit.py\n" > ~/.gdbinit ;;
                gef) echo -e "source ~/gef/gef.py\n" > ~/gdbinit ;;
            esac
        fi
    fi
    echo -e $peda$peda_arm$peda_intel$pwndbg$gef >> ~/.gdbinit
    if [[ $is_err != 0 ]]; then
        exit -1
    fi
    info "info" "gdb install success"

}


function one_gadget_install(){
    info "info" "one_gadget install start"
    one_gadget --version
    if [[ $? != 0 ]]; then
        apt install ruby -y
        gem install one_gadget
    else
        info "wrong" "one_gadget 已经安装，不需要重复安装"
    fi
    info "info" "one_gadget install success"
}

function patchelf_install(){
    info "info" "patchelf install start"
    patch_var=$(patchelf --version 2>/dev/null)
    if [[ $? == 0 ]]; then
        patch_var=$(echo $patch_var| awk -F " " '{ print $2 }')
        get_yesno '当前patchelf版本为'$patch_var',是否安装patchelf-0.15.0' 1 1
        if [[ $? != 0 ]]; then
            info "info" "patchelf install success"
            return 0
        fi
        apt autoremove patchelf
    fi
    git --version 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        apt install git -y
    fi
    make --version 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        apt install make -y
    fi
    wget https://github.com/NixOS/patchelf/releases/download/0.15.0/patchelf-0.15.0.tar.gz  -T 4
    if [[ $? != 0 ]]; then
        info "error" "获取patchelf失败，请检查网络配置"
        exit -1
    fi
    tar zxf "patchelf-0.15.0.tar.gz"
    cd "patchelf-0.15.0"
    ./configure
    make
    make install
    cd ..
    rm -rf "patchelf-0.15.0.tar.gz"
    rm -rf "patchelf-0.15.0"
    info "info" "patchelf install success"
}

function ropper_install(){
    info "info" "ropper install start"
    python3 -m pip install -U pip 2>/dev/null
    while [[ $? != 0 ]]
    do
        get_yesno "python2或pip2不存在，是否尝试安装" 0 1
        if [[ $? == 0 ]]; then
            python_install 2
        else
            return -1
        fi
        python3 -m pip install -U pip 2>/dev/null
    done

    ropper --version 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        pip3 install ropper
        while [[ $? != 0 ]]
        do
            get_yesno "ropper安装失败，是否跳过" 1 1
            pip3 install ropper
        done
    else
        get_yesno "是否升级ropper" 0 1
        if [[ $? == 0 ]]; then
            pip3 install -U ropper
        fi
    fi
    info "info" "ropper install success"
}


function qemu_install(){
    info "info" "qemu install start"
    apt-get install qemu -y
    if [[ $? != 0 ]];then
        info "error" "安装qemu失败，请检查网络配置与apt源配置"
    fi
    apt-get install qemu-kvm -y
    apt-get install qemu-system-x86 -y
    apt-get install qemu-system-arm -y
    apt install qemu-user -y
    apt install make -y
    apt install gcc -y
    apt install git -y
    apt install flex -y
    apt install bison -y
    apt-get install libncurses5-dev -y
    apt-get install gcc-arm-linux-gnueabi -y
    apt-get install zlib1g-dev -y
    apt-get install libglib2.0-0 -y
    apt-get install libglib2.0-dev -y
    apt-get install autoconf -y
    apt-get install automake -y
    apt-get install libtool -y
    apt-get install gettext -y
    info "info" "qemu install success"
}

function binwalk_install(){
    info "info" "binwalk install start"
    binwalk -v 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        wget "https://github.com/ReFirmLabs/binwalk/archive/refs/tags/v2.3.3.zip" -T 4
        unzip "v2.3.3.zip"
        cd "binwalk-2.3.3"
        python3 setup.py install
        while [[ $? != 0 ]];
        do
            get_yesno "python3可能不存在，是否尝试安装" 0 1
            if [[ $? != 0 ]];then
                cd ..
                rm -rf "v2.3.3.zip"
                rm -rf "binwalk-2.3.3"
                return -1
            else
                python_install 3
            fi
            python3 setup.py install
        done
        cd ..
        rm -rf "v2.3.3.zip"
        rm -rf "binwalk-2.3.3"
    else
        info "wrong" "binwalk已安装，无需重新安装"
    fi
    info "info" "binwalk install success"
}

function nc_install(){
    info "info" "nc install start"
    nc -h 2>/dev/null >/dev/null
    if [[ $? == 0 ]] ;then
        if [[ -z $(nc -h 2>&1 | grep -- "-e ") ]]; then
            get_yesno "当前为nc.openbsd版本，是否使用nc.traditional版本" 0 1
            if [[ $? == 0 ]]; then
                apt install -y netcat-traditional
                rm -rf /bin/nc
                ln /bin/nc.traditional /bin/nc
            fi
        else
            info "wrong" "nc已安装，无需重新安装"
        fi
    else
        get_yesno "是否安装nc的traditional版本" 0 1
        if [[ $? == 0 ]] ;then
            apt install nc-traditional -y
            rm -rf /bin/nc
            ln /bin/nc.traditional /bin/nc
        else
            apt insatll nc 
        fi
    fi
    info "info" "nc install success"
}

function alpha_install(){
    info "info" "alpha install start"
    git --version 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        apt install git -y
    fi
    alpha 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        git clone  https://github.com/TaQini/alpha3  ~/alpha
        echo -e "python2 ~/alpha/ALPHA3.py \$*" >> /bin/alpha
        chmod +x /bin/alpha
    else
        info "wrong" "alpha已安装，不需要重新安装"
    fi
    info "info" "alpha install success"
}

function seccomp_install(){
    info "info" "seccomp-tools install start"
    seccomp-tools --version 2>/dev/null >/dev/null
    if [[ $? != 0 ]]; then
        apt install ruby ruby-dev -y
        gem install seccomp-tools
        seccomp-tools --version 2>/dev/null >/dev/null
        while [[ $? != 0 ]]
        do
            get_yesno "seccomp-tools安装失败，是否跳过" 1 1 
            if [[ $? != 0 ]]; then
                gem install seccomp-tools
            else
                break
            fi
            seccomp-tools --version 2>/dev/null >/dev/null
        done
    else
        info "wrong" "seccomp-tools已安装，不需要重新安装"
    fi
    info "info" "seccomp-tools install seccuess"
}


function all_install(){
    change_apt_source
    apt install gcc -y
    apt install git -y
    apt install wget -y
    apt install gdb -y
    apt install unzip -y

    python_install
    pwntools_install
    libcsearch_install
    gdb_install
    one_gadget_install
    patchelf_install
    ropper_install
    qemu_install
    binwalk_install
    nc_install
    alpha_install
    seccomp_install

}

function usage(){
    echo "usage: ./auto_inspwn [mode]"
    echo "    -y  指定使用默认选项"
    echo "    apt            配置apt源"
    echo "    python         安装python2与python3"
    echo "    pwntools       为python2与python3安装pwntools"
    echo "    libcsearcher   为python2与python3安装LibcSearcher"
    echo "    gdb            安装gdb，及其peda,peda-arm,peda-intel,pwndbg,gef插件"
    echo "    one_gadget     安装one_gadget"
    echo "    patchelf       安装patchelf"
    echo "    ropper         安装ropper"
    echo "    qemu           安装qemu"
    echo "    binwalk        安装binwalk"
    echo "    nc             安装nc,netcat-traditional版本为存在-e参数的版本"
    echo "    alpha          安装alpha，用于为shellcode进行编码"
    echo "    seccomp        安装seccomp-tools"
    echo "    all            执行以上所有"
}

function main(){ 
    if [[ -z $* ||  $* == "-y" ]]; then
        usage
        return
    fi
    if [[ $* =~ "-y" ]];then
        is_def=0
    fi
    
    for i in $*
    do
        case $i in 
            apt)
                change_apt_source
                apt install gcc -y
                apt install git -y
                apt install wget -y
                apt install gdb -y
                apt install unzip -y
                ;;
            python)   python_install ;;
            pwntools)    pwntools_install  ;;
            libcsearcher)    libcsearch_install  ;;
            gdb)    gdb_install ;;
            one_gadget)    one_gadget_install ;;
            patchelf)    patchelf_install ;;
            ropper)    ropper_install ;;
            qemu)    qemu_install ;;
            binwalk)    binwalk_install ;;
            nc)    nc_install ;;
            alpha)    alpha_install ;;
            seccomp)    seccomp_install ;;
            all) all_install ;;
        esac
    done
}
main $*
