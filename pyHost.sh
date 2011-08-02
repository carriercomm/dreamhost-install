#!/bin/bash -e
# =================================================
# = pyHost version 1.5
# = 
# = Created by Tommaso Lanza, under the influence
# = of the guide published by Andrew Watts at:
# = http://andrew.io/weblog/2010/02/installing-python-2-6-virtualenv-and-VirtualEnvWrapper-on-dreamhost/
# =
# = This script automates the installation, download and
# = compiling of Python, Mercurial, VirtualEnv in the home folder.
# = It includes a number of dependencies needed by some Python modules.
# = It has been tested on Dreamhost on a shared server running Debian.
# = It should work with other hosts, but it hasn't been tested.
#
# Changelog
#
# Updated Aug 1 2011 - Kristi Tsukida <kristi.dev@gmail.com>
# * Updated version numbers and urls
# * Use pip to install python packages
# * Check for directories before creating them
# * Pass --quiet flags and redirect to /dev/null to reduce output
# * Add log files
# * Download into the current directory
# * Add uninstall
# * Remove lesscss gem (repo old, and lesscss seems to be in js now)
#
# TODO: install into $pH_install instead of $pH_install/local so we don't taint the virtualenv at $pH_install/local
# TODO: change script url in .bashrc
# 
# Ignore these errors:
# * Openssl
#     (I don't know why)
#     Use of uninitialized value $output in pattern match (m//) at asm/md5-x86_64.pl line 115
# * Readline 
#     (Makefile is trying to move existing libs, but there are no
#     existing files to move)
#     mv: cannot stat 'opt/local/lib/libreadline.a': No such file or directory
#     mv: cannot stat 'opt/local/lib/libhistory.a': No such file or directory
# * Berkeley DB
#     (I don't know why)
#     libtool.m4: error: problem compiling CXX test program
#
# Original script ver 1.5 tmslnz, May 2010
#
#
# =================================================
#


verbose=true

# ##################
# Directory mangling
####################
# First, set your variables here in case you
# want different versions or directories:

# Directory to store the source archives
pH_DL="$PWD/downloads"

# Directory to install these packages
pH_install="$HOME/opt"
pH_virtenv="$HOME/opt/local"

# Ruby Gems dir with prefix ~/
pH_Gem=.gem

pH_log="log.txt"
pH_error="error.txt"

pH_script_url="http://bitbucket.org/tmslnz/python-dreamhost-batch/src/tip/pyHost.sh"

# Package versions
#
# Comment out anything you don't want to install...
# ...if you are really sure you have all 
# necessary libraries installed already.

pH_Python=2.7.2
pH_setuptools="0.6c11"
pH_Mercurial=1.9
pH_Git=1.7.6
pH_Django=1.3
pH_VirtualEnv=1.6.4
pH_VirtualEnvWrapper=2.7.1
pH_SSL=1.0.0d
pH_Readline=6.2
pH_Tcl=8.5.10
pH_Tk=8.5.10
pH_Berkeley_47x=4.7.25
pH_Berkeley_48x=4.8.30
pH_Berkeley_50x=5.2.28
pH_BZip=1.0.6
pH_SQLite=3070701 #3.7.7.1
pH_cURL=7.21.7
pH_Dulwich=0.7.1
pH_bsddb=5.2.0



# Sets the correct version of Berkeley DB to use and download
# by looking at the Python version number
if [[ ${pH_Python:0:3} == "2.6" ]]; then
    pH_Berkeley=$pH_Berkeley_47x
elif [[ ${pH_Python:0:3} == "2.7" ]]; then
    pH_Berkeley=$pH_Berkeley_48x
elif [[ ${pH_Python:0:1} == "3" ]]; then
    pH_Berkeley=$pH_Berkeley_50x
fi

function print {
    if [[ "$verbose" == "true" ]] || [[ "$verbose" -gt 0 ]]  ; then
        echo "$@"
    fi
}

function ph_install_setup {
    print "Start installation"
    # Let's see how long it takes to finish;
    start_time=$(date +%s)

    PH_OLD_PATH=$PATH
    PH_OLD_PYTHONPATH=$PYTHONPATH
    
    # Make a backup copy of the current $pH_install folder if it exists.
    if [[ -e $pH_install ]]; then
        cp --archive $pH_install $pH_install.backup
    fi
    mkdir --parents $pH_install $pH_DL
    mkdir --parents --mode=775 $pH_install/local/lib
    
    # Backup and modify .bashrc
    if [[ ! -e ~/.bashrc-pHbackup ]] ; then
        cp ~/.bashrc ~/.bashrc-pHbackup
        cat >> ~/.bashrc <<DELIM


######################################################################
# The following lines were added by the script pyHost.sh from:
# $pH_script_url
# on $(date -u)
######################################################################

export PATH=$pH_install/local/bin:$pH_install/Python-$pH_Python/bin:$pH_install/db-$pH_Berkeley/bin:\$PATH
export PYTHONPATH=$pH_install/local/lib/python${pH_Python:0:3}/site-packages:\$PYTHONPATH

DELIM

    fi

    source ~/.bashrc

    # ###################
    # Download and unpack
    #####################
    
    # GCC
    # ##################################################################
    # Set temporary session paths for and variables for the GCC compiler
    # 
    # Specify the right version of Berkeley DB you want to use, see
    # below for DB install scripts.
    ####################################################################
    export LD_LIBRARY_PATH=\
$pH_install/local/lib:\
$pH_install/db-$pH_Berkeley/lib:\
$LD_LIBRARY_PATH
    
    export LD_RUN_PATH=$LD_LIBRARY_PATH
    
    export LDFLAGS="\
    -L$pH_install/db-$pH_Berkeley/lib \
    -L$pH_install/local/lib"
    
    export CPPFLAGS="\
    -I$pH_install/local/include \
    -I$pH_install/local/include/openssl \
    -I$pH_install/db-$pH_Berkeley/include \
    -I$pH_install/local/include/readline"
    
    export CXXFLAGS=$CPPFLAGS
    export CFLAGS=$CPPFLAGS
    
}


# ############################
# Download Compile and Install
##############################

# OpenSSL (required by haslib)
function ph_openssl {
    print "    installing OpenSSL $pH_SSL..."
    cd $pH_DL
    if [[ ! -e openssl-$pH_SSL ]] ; then
        wget -q http://www.openssl.org/source/openssl-$pH_SSL.tar.gz
        rm -rf openssl-$pH_SSL
        tar -xzf openssl-$pH_SSL.tar.gz
        cd openssl-$pH_SSL
        ./config --prefix=$pH_install/local --openssldir=$pH_install/local/openssl shared > /dev/null
    else
        cd openssl-$pH_SSL
    fi
    make --silent > /dev/null
    make install --silent > /dev/null
    cd $pH_DL
}

# Readline
function ph_readline {
    print "    installing Readline $pH_Readline..."
    cd $pH_DL
    if [[ ! -e readline-$pH_Readline ]] ; then
        wget -q ftp://ftp.gnu.org/gnu/readline/readline-$pH_Readline.tar.gz
        rm -rf readline-$pH_Readline
        tar -xzf readline-$pH_Readline.tar.gz
    fi
    cd readline-$pH_Readline
    ./configure --prefix=$pH_install/local --quiet
    make --silent
    make install --silent >/dev/null
    cd $pH_DL
}

# Tcl
function ph_tcl {
    print "    installing Tcl $pH_Tcl..."
    cd $pH_DL
    if [[ ! -e tcl$pH_Tcl-src ]] ; then
        wget -q http://prdownloads.sourceforge.net/tcl/tcl$pH_Tcl-src.tar.gz
        rm -rf tcl$pH_Tcl-src
        tar -xzf tcl$pH_Tcl-src.tar.gz
    fi
    cd tcl$pH_Tcl/unix
    ./configure --prefix=$pH_install/local --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd $pH_DL
    #rm -f $pH_install/local/lib/libtcl${pH_Tcl:0:1}.so
    #rm -f $pH_install/local/lib/libtcl.so
    #ln -s $pH_install/local/lib/libtcl${pH_Tcl:0:3}.so $pH_install/local/lib/libtcl${pH_Tcl:0:1}.so
    #ln -s $pH_install/local/lib/libtcl${pH_Tcl:0:3}.so $pH_install/local/lib/libtcl.so
}

# Tk (WTF?!)
function ph_tk {
    print "    installing Tk $pH_Tk..."
    cd $pH_DL
    if [[ ! -e tk$pH_Tcl-src ]] ; then
        wget -q http://prdownloads.sourceforge.net/tcl/tk$pH_Tk-src.tar.gz
        rm -rf tk$pH_Tk-src
        tar -xzf tk$pH_Tk-src.tar.gz
    fi
    cd tk$pH_Tk/unix
    ./configure --prefix=$pH_install/local --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd $pH_DL
    #rm -f $pH_install/local/lib/libtk${pH_Tk:0:1}.so
    #rm -f $pH_install/local/lib/libtk.so
    #ln -s $pH_install/local/lib/libtk${pH_Tk:0:3}.so $pH_install/local/lib/libtk${pH_Tk:0:1}.so
    #ln -s $pH_install/local/lib/libtk${pH_Tk:0:3}.so $pH_install/local/lib/libtk.so
}

# Oracle Berkeley DB
function ph_berkeley {
    print "    installing Berkeley DB $pH_Berkeley..."
    cd $pH_DL
    if [[ ! -e db-$pH_Berkeley ]] ; then
        wget -q http://download.oracle.com/berkeley-db/db-$pH_Berkeley.tar.gz
        rm -rf db-$pH_Berkeley
        tar -xzf db-$pH_Berkeley.tar.gz
    fi
    cd db-$pH_Berkeley/build_unix
    ../dist/configure  --quiet\
    --prefix=$pH_install/db-$pH_Berkeley \
    --enable-tcl \
    --with-tcl=$pH_install/local/lib
    make --silent >/dev/null
    make install --silent >/dev/null
    cd $pH_DL
}

# Bzip (required by hgweb)
function ph_bzip {
    print "    installing BZip $pH_BZip..."
    cd $pH_DL
    if [[ ! -e bzip2-$pH_BZip ]] ; then
        wget -q http://www.bzip.org/$pH_BZip/bzip2-$pH_BZip.tar.gz
        rm -rf bzip2-$pH_BZip
        tar -xzf bzip2-$pH_BZip.tar.gz
    fi
    cd bzip2-$pH_BZip
    make -f Makefile-libbz2_so --silent >/dev/null
    make --silent >/dev/null
    make install PREFIX=$pH_install/local --silent >/dev/null
    #cp libbz2.so.${pH_BZip} $pH_install/local/lib
    #rm -f $pH_install/local/lib/libbz2.so.${pH_BZip}
    #ln -s $pH_install/local/lib/libbz2.so.${pH_BZip:0:3}.4 $pH_install/local/lib/libbz2.so.${pH_BZip:0:3}
    cd $pH_DL
}

# SQLite
function ph_sqlite {
    print "    installing SQLite $pH_SQLite..."
    cd $pH_DL
    if [[ ! -e sqlite-autoconf-$pH_SQLite ]] ; then
        wget -q http://www.sqlite.org/sqlite-autoconf-$pH_SQLite.tar.gz
        rm -rf sqlite-autoconf-$pH_SQLite
        tar -xzf sqlite-autoconf-$pH_SQLite.tar.gz
    fi
    cd sqlite-autoconf-$pH_SQLite
    ./configure --prefix=$pH_install/local --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd $pH_DL
}

# bsddb
function ph_bsddb {
    print "    installing bsddb $pH_bsddb..."
    cd $pH_DL
    if [[ ! -e bsddb3-5.0.0 ]] ; then
        wget -q http://pypi.python.org/packages/source/b/bsddb3/bsddb3-5.0.0.tar.gz
        rm -rf bsddb3-5.0.0
        tar -xzf bsddb3-5.0.0.tar.gz
    fi
}

# Python
function ph_python {
    print "    installing Python $pH_Python..."
    # Append Berkeley DB to EPREFIX. Used by Python setup.py
    export EPREFIX=$pH_install/db-$pH_Berkeley/lib:$EPREFIX
    cd $pH_DL
    wget -q http://python.org/ftp/python/$pH_Python/Python-$pH_Python.tgz
    rm -rf Python-$pH_Python
    tar -xzf Python-$pH_Python.tgz
    cd Python-$pH_Python
    export CXX="g++" # disable warning message about using g++
    ./configure --prefix=$pH_install/Python-$pH_Python --quiet
    make --silent | tail
    make install --silent >/dev/null
    # Unset EPREFIX. Used by Python setup.py
    export EPREFIX=
    cd $pH_DL

    #export PATH=$pH_install/Python-$pH_Python/bin:$PATH
    #export PYTHONPATH=$pH_install/local/lib/python${pH_Python:0:3}/site-packages:\$PYTHONPATH
}

# Python setuptools
function ph_setuptools {
    print "    installing Python setuptools $pH_setuptools..."
    cd $pH_DL
    wget http://pypi.python.org/packages/${pH_Python:0:3}/s/setuptools/setuptools-$pH_setuptools-py${pH_Python:0:3}.egg
    sh setuptools-$pH_setuptools-py${pH_Python:0:3}.egg
    easy_install -q pip
}

# Mercurial
function ph_mercurial {
    print "    installing Mercurial $pH_Mercurial..."
    cd $pH_DL
    
    # docutils required by mercurial
    pip install -q -U docutils

    wget -q http://mercurial.selenic.com/release/mercurial-$pH_Mercurial.tar.gz
    rm -rf mercurial-$pH_Mercurial
    tar -xzf mercurial-$pH_Mercurial.tar.gz
    cd mercurial-$pH_Mercurial
    make install PREFIX=$pH_install/local --silent >/dev/null
    cd $pH_DL
    cat >> ~/.hgrc <<DELIM

# Added by pyHost.sh from:
# http://bitbucket.org/tmslnz/python-dreamhost-batch/src/tip/pyHost.sh
# on $(date -u)
[ui]
editor = vim
ssh = ssh -C

[extensions]
rebase =
color =
bookmarks =
convert=
# nullifies Dreamhost's shitty system-wide .hgrc
hgext.imerge = !

[color]
status.modified = magenta bold
status.added = green bold
status.removed = red bold
status.deleted = cyan bold
status.unknown = blue bold
status.ignored = black bold

[hooks]
# Prevent "hg pull" if MQ patches are applied.
prechangegroup.mq-no-pull = ! hg qtop > /dev/null 2>&1
# Prevent "hg push" if MQ patches are applied.
preoutgoing.mq-no-push = ! hg qtop > /dev/null 2>&1
# End added by pyHost.sh

DELIM
}

# VirtualEnv
function ph_virtualenv {
    print "    installing VirtualEnv $pH_VirtualEnv..."
    cd $pH_DL
    wget -q http://pypi.python.org/packages/source/v/virtualenv/virtualenv-$pH_VirtualEnv.tar.gz
    rm -rf virtualenv-$pH_VirtualEnv
    tar -xzf virtualenv-$pH_VirtualEnv.tar.gz
    cd virtualenv-$pH_VirtualEnv

    # DEBUG
    echo ===DEBUG=== >> debug.txt
    echo "${PATH//:/$'\n'}" >> debug.txt
    echo ===DEBUG=== >> debug.txt
    which python >> debug.txt
    which pip >> debug.txt
    pip freeze >> debug.txt

    # May need to use 'python2.5' instead of 'python' here
    # as the script may require a *system* installation of python
    python virtualenv.py $pH_install/local --no-site-packages

    # DEBUG
    echo ===DEBUG=== >> debug.txt
    which python >> debug.txt
    which pip >> debug.txt
    pip freeze >> debug.txt

    pip install -q -U virtualenv 
    #pip install -q -U virtualenvwrapper

    #DEBUG
    echo ===DEBUG=== >> debug.txt
    which python >> debug.txt
    which pip >> debug.txt
    pip freeze >> debug.txt
    #easy_install virtualenv
    #cd ..

    ##wget -q http://www.doughellmann.com/downloads/virtualenvwrapper-$pH_VirtualEnvWrapper.tar.gz
    #wget -q http://pypi.python.org/packages/source/v/virtualenvwrapper/virtualenvwrapper-$pH_VirtualEnvWrapper.tar.gz
    #rm -rf virtualenvwrapper-$pH_VirtualEnvWrapper
    #tar -xzf virtualenvwrapper-$pH_VirtualEnvWrapper.tar.gz
    #cd virtualenvwrapper-$pH_VirtualEnvWrapper
    #python setup.py install
    #cp virtualenvwrapper.sh $pH_install/
    #[[ -e $HOME/.virtualenvs ]] || mkdir $HOME/.virtualenvs
    cd $pH_DL
    
    # Virtualenv to .bashrc
    #cat >> ~/.bashrc <<DELIM
## Virtualenv wrapper script
#export WORKON_HOME=\$HOME/.virtualenvs
#source virtualenvwrapper.sh
#DELIM
    source ~/.bashrc
}

# Django framework
function ph_django {
    print "    installing Django $pH_Django..."
    cd $pH_DL
    #wget -q http://www.djangoproject.com/download/$pH_Django/tarball/
    #rm -rf Django-$pH_Django
    #tar -xzf Django-$pH_Django.tar.gz
    #cd Django-$pH_Django
    #python setup.py install
    pip install -q -U django
    cd $pH_DL
}

# cURL (for Git to pull remote repos)
function ph_curl {
    print "    installing cURL $pH_cURL..."
    cd $pH_DL
    wget -q http://curl.haxx.se/download/curl-$pH_cURL.tar.gz
    rm -rf curl-$pH_cURL
    tar -xzf curl-$pH_cURL.tar.gz
    cd curl-$pH_cURL
    ./configure --prefix=$pH_install/local --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd $pH_DL
}

# Git
# NO_MMAP is needed to prevent Dreamhost killing git processes
function ph_git {
    print "    installing Git $pH_Git..."
    cd $pH_DL
    wget -q http://kernel.org/pub/software/scm/git/git-$pH_Git.tar.gz
    rm -rf git-$pH_Git
    tar -xzf git-$pH_Git.tar.gz
    cd git-$pH_Git
    ./configure --prefix=$pH_install/local NO_MMAP=1 --quiet
    make --silent >/dev/null
    make install --silent >/dev/null
    cd $pH_DL
}

# Dulwich
function ph_dulwich {
    print "    installing Dulwich $pH_Dulwich..."
    cd $pH_DL
    wget -q http://samba.org/~jelmer/dulwich/dulwich-$pH_Dulwich.tar.gz
    rm -rf dulwich-$pH_Dulwich
    tar -xzf dulwich-$pH_Dulwich.tar.gz
    cd dulwich-$pH_Dulwich
    python setup.py --quiet install 
    cd $pH_DL
}

# Hg-Git
function ph_hggit {
    print "    installing hg-git $pH_hggit..."
    cd $pH_DL
    [ ! -e hg-git ] && mkdir hg-git
    cd hg-git
    wget -q http://github.com/schacon/hg-git/tarball/master
    tar -xzf *
    hg_git_dir=$(ls -dC */)
    cd $hg_git_dir
    python setup.py install
    cd $pH_DL
    # Virtualenv to .bashrc
    cat >> ~/.hgrc <<DELIM
    
# Added by pyHost.sh from:
# http://bitbucket.org/tmslnz/python-dreamhost-batch/src/tip/pyHost.sh
# on $(date -u)
[extensions]
hggit =
# End added by pyHost.sh

DELIM
}



function ph_install {

    # Download and install
    if test "${pH_SSL+set}" == set ; then
        ph_openssl
    fi
    if test "${pH_Readline+set}" == set ; then
        ph_readline
    fi
    if test "${pH_Tcl+set}" == set ; then
        ph_tcl
    fi
    if test "${pH_Tk+set}" == set ; then
        ph_tk
    fi
    if test "${pH_Berkeley+set}" == set ; then
        ph_berkeley
    fi
    if test "${pH_BZip+set}" == set ; then
        ph_bzip
    fi
    if test "${pH_SQLite+set}" == set ; then
        ph_sqlite
    fi
    if test "${pH_bsddb+set}" == set ; then
        ph_bsddb
    fi
    if test "${pH_Python+set}" == set ; then
        ph_python
    fi
    if test "${pH_setuptools+set}" == set ; then
        ph_setuptools
    fi
    if test "${pH_Mercurial+set}" == set ; then
        ph_mercurial
    fi
    if test "${pH_VirtualEnv+set}" == set ; then
        ph_virtualenv
    fi
    if test "${pH_Django+set}" == set ; then
        ph_django
    fi
    if test "${pH_cURL+set}" == set ; then
        ph_curl
    fi
    if test "${pH_Git+set}" == set ; then
        ph_git
    fi
    if test "${pH_Dulwich+set}" == set ; then
        ph_dulwich
        ph_hggit
    fi
    
    cd ~
    finish_time=$(date +%s)
    echo "pyHost.sh completed the installation in $((finish_time - start_time)) seconds."
}

function ph_uninstall {
    echo "Removing $pH_install"
    rm -rf $pH_install $pH_install.backup

    echo "Removing $pH_error and $pH_log"
    rm -f $pH_error $pH_log

    echo ""
    read -n1 -p "Delete $pH_DL? [y,n]" choice 
    case $choice in  
      y|Y) rm -rf $pH_DL ;;
    esac
    echo ""

    if [[ -e $HOME/.bashrc-pHbackup ]] ; then
        echo "Restoring old ~/.bashrc"
        mv $HOME/.bashrc-pHbackup $HOME/.bashrc
    fi

    echo ""
    echo "There may also be entries in your ~/.bashrc and ~/.hgrc which need removing."
    echo "You may want delete $pH_Gem and ~/.virtualenvs too"

    echo ""
    choice='n'
    [[ -e $HOME/.virtualenvs ]] && read -n1 -p "Delete $HOME/.virtualenvs? [y,n]" choice 
    case $choice in  
      y|Y) rm -rf $HOME/.virtualenvs ;;
    esac
    echo ""

    echo ""
    choice='n'
    [[ -e $HOME/.hgrc ]] && read -n1 -p "Delete $HOME/.hgrc? [y,n]" choice 
    case $choice in  
      y|Y) rm -rf $HOME/.hgrc ;;
    esac
    echo ""

    echo ""
    echo "Done."
    echo ""
    echo "You should log out and log back in so that environment variables will be reset."
    echo ""
}

# Parse input arguments
if [ "$1" == "uninstall" ] ; then
    ph_uninstall
elif [ "$1" == "install" ] ; then
    {
        ph_install_setup
        ph_install
    } 2>&1 | tee $pH_log
elif [ -z "$1" ] ; then
    echo "did you mean to install?  run '$0 install'"
else
    # DEBUG HACK
    # run individual install functions
    # Ex to run ph_python and ph_mercurial
    #    ./pyHost.sh python mercurial
    ph_install_setup 
    for x in $1 ; do
        "ph_$x"
    done
fi


