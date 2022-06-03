#!/bin/bash

#Initial version Patrick Mulrooney
#Last updated by Caroline Papadopoulos 5/31/2022

# You can change these, but this is what I built against and know works on Comet.
export JEDISTACKREPO="https://github.com/JCSDA/jedi-stack.git"
export JEDISTACKBRANCH="develop"
# cpapadop previous version before atlas upgrade to atlas ecmwf 0.29.0
#export JEDISTACKCOMMIT="8753d606a00dd4ce29b95b6ce0e43fc5f66169c4"
export JEDISTACKCOMMIT="6e3145fe955d2023c553f0c73d2ce6094133a15f"

export CCONFIGURELOG="${PWD}/comet-jedi-stack.`/bin/date -Iseconds`.log"
export CBUILDLOG="${PWD}/comet-jedi-stack-builds.`/bin/date -Iseconds`.log"


function cecho
{
  echo -e "\n$(/usr/bin/date "+%T") ## $*"
}
function cechon
{
  echo -e "$(/usr/bin/date "+%T") ## $*"
}

cecho "Writing the following logs:" |& tee -a "${CCONFIGURELOG}"
cechon " Log of what you see on the screen: ${CCONFIGURELOG}" |& tee -a "${CCONFIGURELOG}"
cechon " Log of the verbose build output (hidden): ${CBUILDLOG}" |& tee -a "${CCONFIGURELOG}"

# For downloads
export ftp_proxy=10.21.2.4:3128

if [[ `hostname|sed 's/\..*//'|egrep -c 'comet-..-..'` -ne 1 ]]
then
  cecho " Has to be run on a compute node, use the following command to launch an interactive session:" |& tee -a "${CCONFIGURELOG}"
  echo "$ srun --partition=compute --pty --nodes=1 --wait=0 --export=ALL -t 48:00:00 /bin/bash" |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

cecho "Purging any modules to remove conflicts..." |& tee -a "${CCONFIGURELOG}"
eval `/usr/bin/modulecmd bash purge` |& tee -a "${CCONFIGURELOG}"
unset LD_LIBRARY_PATH


cecho "Moving up one directory..." |& tee -a "${CCONFIGURELOG}"
cd .. 
cecho "Working in ${PWD}..." |& tee -a "${CCONFIGURELOG}"

which conda > /dev/null 2>&1
if [[ $? -eq 1 ]]
then
  cecho "This setup requires Conda, installing Miniconda in this directory..." |& tee -a "${CCONFIGURELOG}"

  # Set by default and upsets the install
  unset PYTHONPATH

  cechon " -Downloading..." |& tee -a "${CCONFIGURELOG}"
  /bin/wget -nv https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh |& tee -a "${CCONFIGURELOG}"
  cechon " -Installing (takes a few minutes)... $(/bin/date)" |& tee -a "${CCONFIGURELOG}"
  /bin/bash Miniconda3-latest-Linux-x86_64.sh -b -p `pwd`/miniconda3 >> "${CCONFIGURELOG}" 2>&1

  cechon " -Activating environment" |& tee -a "${CCONFIGURELOG}"
  source ./miniconda3/bin/activate 
  cechon " -Confirming it is active" |& tee -a "${CCONFIGURELOG}"
  conda env list > /dev/null 2>&1
  if [[ $? -ne 0 ]]
  then
    cechon " -ERROR! Failed to get exit code zero when we ran... conda env list" |& tee -a "${CCONFIGURELOG}"
    exit 1
  fi
  cechon " -Done and looks like it is working!" |& tee -a "${CCONFIGURELOG}"
else
  CCONDAROOT=${CONDA_EXE%%/conda}
  if [ ! -f "${CCONDAROOT}/activate" ]
  then
    cechon "ERROR! Failed find 'bin/activate' file to source for current conda environment: ${CCONDAROOT}" |& tee -a "${CCONFIGURELOG}"
    exit 1
  fi
  cecho "Sourcing ${CCONDAROOT}/activate so conda works properly..." |& tee -a "${CCONFIGURELOG}"

  source "${CCONDAROOT}/activate"
fi

if [[ -d ~/.lmod.d ]] 
then 
  cecho "Removing any lmod cache (causes issues)..." |& tee -a "${CCONFIGURELOG}"
  rm -rfv ~/.lmod.d |& tee -a "${CCONFIGURELOG}"
fi

cecho "Creating minimal conda environment in `pwd`/env" |& tee -a "${CCONFIGURELOG}"
conda create -y  -p ${PWD}/env >> "${CCONFIGURELOG}" 2>&1
cecho "Activating new environment..." |& tee -a "${CCONFIGURELOG}"
conda activate ${PWD}/env >> "${CCONFIGURELOG}" 2>&1

if [[ "x${CONDA_PREFIX}" != "x${PWD}/env" ]]
then
  cecho "ERROR! Not in the expected environment..." |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

cecho "Installing lmod & python..." |& tee -a "${CCONFIGURELOG}"
conda install -y -c conda-forge lmod==8.6.18 python==3.9.12 >> "${CCONFIGURELOG}" 2>&1

cecho "Installing git & git-lfs..." |& tee -a "${CCONFIGURELOG}"
conda install -y -c conda-forge git git-lfs >> "${CCONFIGURELOG}" 2>&1

cecho "Setting JEDI_OPT variable to ${PWD}/modules..." |& tee -a "${CCONFIGURELOG}"
export JEDI_OPT=${PWD}/modules 

cecho "Adding ${JEDI_OPT}/core, /share/apps/compute/modulefiles/applications, & /share/apps/compute/modulefiles/ to module search path" |& tee -a "${CCONFIGURELOG}"
module use /share/apps/compute/modulefiles /share/apps/compute/modulefiles/applications $JEDI_OPT/modulefiles/core 

cecho "Logging the available modules..." |& tee -a "${CCONFIGURELOG}"
module avail >> "${CCONFIGURELOG}" 2>&1

if [[ `module avail |& grep -c "intel/2020u4"` -ne 1 ]]
then
  cecho "ERROR! Did not find intel/2020u4 in list of modules..." |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

if [[ `module avail |& grep -c "intelmpi/2020u4"` -ne 1 ]]
then
  cecho "ERROR! Did not find intelmpi/2020u4 in list of modules..." |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

cecho "Cloning jedi-stack repo from  ${JEDISTACKREPO}..." |& tee -a "${CCONFIGURELOG}"
git clone ${JEDISTACKREPO} |& tee -a "${CCONFIGURELOG}"

cecho "Moving into jedi-stack directory..." |& tee -a "${CCONFIGURELOG}"
cd jedi-stack 

cecho "Checking out ${JEDISTACKBRANCH} branch..." |& tee -a "${CCONFIGURELOG}"
git checkout ${JEDISTACKBRANCH} |& tee -a "${CCONFIGURELOG}"

cecho "Checking out ${JEDISTACKCOMMIT} commit..." |& tee -a "${CCONFIGURELOG}"
git checkout ${JEDISTACKCOMMIT} |& tee -a "${CCONFIGURELOG}"

cecho "Creating patch file (0001-comet.patch)..." |& tee -a "${CCONFIGURELOG}"
cat > 0001-comet.patch << 'EOL'
From a0c0647df28af84d23d3ea94793f6d7a0f3bc9aa Mon Sep 17 00:00:00 2001
From: cpapadop <cpapadopoulos@ucsd.edu>
Date: Fri, 27 May 2022 11:19:19 -0700
Subject: [PATCH] Updated stack changes for comet

---
 buildscripts/build_stack.sh                   |  2 +-
 buildscripts/config/config_custom.sh          | 98 +++++++++++++++++--
 buildscripts/libs/build_zlib.sh               |  2 +-
 .../compilerVersion/intelmpi/intelmpi.lua     | 35 +++++++
 .../jedi-intelmpi/jedi-intelmpi.lua           | 30 ++++++
 modulefiles/core/jedi-intel/jedi-intel.lua    |  2 +
 6 files changed, 160 insertions(+), 9 deletions(-)
 create mode 100644 modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua
 create mode 100644 modulefiles/compiler/compilerName/compilerVersion/jedi-intelmpi/jedi-intelmpi.lua

diff --git a/buildscripts/build_stack.sh b/buildscripts/build_stack.sh
index 75d1e59..37e9d53 100755
--- a/buildscripts/build_stack.sh
+++ b/buildscripts/build_stack.sh
@@ -54,7 +54,7 @@ else
 fi
 
 # Choose which modules you wish to install
-$MODULES && source ${JEDI_BUILDSCRIPTS_DIR}/config/choose_modules.sh
+#$MODULES && source ${JEDI_BUILDSCRIPTS_DIR}/config/choose_modules.sh
 
 # this is needed to set environment variables if modules are not used
 $MODULES || no_modules $1
diff --git a/buildscripts/config/config_custom.sh b/buildscripts/config/config_custom.sh
index 757808c..9616ce9 100644
--- a/buildscripts/config/config_custom.sh
+++ b/buildscripts/config/config_custom.sh
@@ -5,8 +5,8 @@
 
 
 # Compiler/MPI combination
-export JEDI_COMPILER="gnu/9.3.0"
-export JEDI_MPI="openmpi/4.0.3"
+export JEDI_COMPILER="intel/2020u4"
+export JEDI_MPI="intelmpi/2020u4"
 #export MPI="mpich/3.2.1"
 
 #export JEDI_COMPILER="intel/19.0.5"
@@ -22,15 +22,16 @@ export JEDI_MPI="openmpi/4.0.3"
 #             as installed by package managers like apt-get or hombrewo.
 #             This is a common option for, e.g., gcc/g++/gfortrant
 # from-source: This is to build from source
-export COMPILER_BUILD="native-pkg"
-export MPI_BUILD="from-source"
+export COMPILER_BUILD="native-module"
+export MPI_BUILD="native-module"
 # Build options
-export PREFIX=/opt/modules
-export USE_SUDO=Y
+export PREFIX=CHANGEME
+export USE_SUDO=N
+export JEDI_STACK_DISABLE_COMPILER_VERSION_CHECK=1
 export PKGDIR=pkg
 export LOGDIR=buildscripts/log
 export OVERWRITE=N
-export NTHREADS=4
+export NTHREADS=24
 export   MAKE_CHECK=N
 export MAKE_VERBOSE=Y
 export   MAKE_CLEAN=N
@@ -42,3 +43,86 @@ export FFLAGS=""
 export CFLAGS=""
 export CXXFLAGS=""
 export LDFLAGS=""
+
+# Minimal JEDI Stack
+export      STACK_BUILD_CMAKE=Y
+export     STACK_BUILD_GITLFS=N
+export    STACK_BUILD_UDUNITS=Y
+export       STACK_BUILD_ZLIB=Y
+export       STACK_BUILD_SZIP=Y
+export     STACK_BUILD_LAPACK=Y
+export STACK_BUILD_BOOST_HDRS=Y
+export       STACK_BUILD_BUFR=Y
+export     STACK_BUILD_EIGEN3=Y
+export       STACK_BUILD_HDF5=Y
+export    STACK_BUILD_PNETCDF=Y
+export     STACK_BUILD_NETCDF=Y
+export      STACK_BUILD_NCCMP=Y
+export    STACK_BUILD_ECBUILD=Y
+export      STACK_BUILD_ECKIT=Y
+export      STACK_BUILD_FCKIT=Y
+export      STACK_BUILD_ATLAS=Y
+export   STACK_BUILD_GSL_LITE=Y
+export   STACK_BUILD_PYBIND11=Y
+
+# Optional Additions
+export       STACK_BUILD_ECCODES=Y
+export           STACK_BUILD_ODC=N
+export           STACK_BUILD_PIO=Y
+export          STACK_BUILD_GPTL=N
+export           STACK_BUILD_NCO=N
+export        STACK_BUILD_PYJEDI=N
+export      STACK_BUILD_NCEPLIBS=N
+export          STACK_BUILD_JPEG=N
+export           STACK_BUILD_PNG=N
+export        STACK_BUILD_JASPER=N
+export        STACK_BUILD_XERCES=N
+export        STACK_BUILD_TKDIFF=N
+export    STACK_BUILD_BOOST_FULL=N
+export          STACK_BUILD_ESMF=N
+export      STACK_BUILD_BASELIBS=N
+export     STACK_BUILD_PDTOOLKIT=N
+export          STACK_BUILD_TAU2=N
+export          STACK_BUILD_CGAL=N
+export          STACK_BUILD_GEOS=N
+export        STACK_BUILD_SQLITE=N
+export          STACK_BUILD_PROJ=N
+export           STACK_BUILD_FMS=N
+export          STACK_BUILD_JSON=Y
+export STACK_BUILD_JSON_SCHEMA_VALIDATOR=Y
+export        STACK_BUILD_ECFLOW=N
+
+# Used to disable some of the build when you run a second time due to error, if all goes well you
+# should not need to use this. The modules should be in order of install.
+SECONDRUN=false
+if [[ "$SECONDRUN" = true ]]
+then
+    export      STACK_BUILD_CMAKE=N
+    export    STACK_BUILD_UDUNITS=N
+    export       STACK_BUILD_ZLIB=N
+    export       STACK_BUILD_SZIP=N
+    export     STACK_BUILD_LAPACK=N
+    export STACK_BUILD_BOOST_HDRS=N
+    export     STACK_BUILD_EIGEN3=N
+    export       STACK_BUILD_BUFR=N
+    export    STACK_BUILD_ECBUILD=N
+    export   STACK_BUILD_GSL_LITE=N
+    export   STACK_BUILD_PYBIND11=N
+    export       STACK_BUILD_HDF5=N
+    export    STACK_BUILD_PNETCDF=N
+    export      STACK_BUILD_NCCMP=N
+    export      STACK_BUILD_ECKIT=N
+    export      STACK_BUILD_FCKIT=N
+    export      STACK_BUILD_ATLAS=N
+    export    STACK_BUILD_ECCODES=N
+fi
+
+# C++-14 compliant compiler settings
+# set / export these variables when building for Intel compiler(s)
+if [[ "$JEDI_COMPILER" =~ .*"intel"* ]]; then
+    export CXXFLAGS="-gxx-name=/share/apps/compute/gnu/v8.3.0/bin/g++ -Wl,-rpath,/share/apps/compute/gnu/v8.3.0/lib64"
+    export LDFLAGS="-gxx-name=/share/apps/compute/gnu/v8.3.0/bin/g++ -Wl,-rpath,/share/apps/compute/gnu/v8.3.0/lib64"
+    #export CXXFLAGS="-std=c++14"
+    #export LDFLAGS="-std=c++14"
+fi
+
diff --git a/buildscripts/libs/build_zlib.sh b/buildscripts/libs/build_zlib.sh
index c4d94f1..1b15235 100755
--- a/buildscripts/libs/build_zlib.sh
+++ b/buildscripts/libs/build_zlib.sh
@@ -14,7 +14,7 @@ compiler=$(echo $JEDI_COMPILER | sed 's/\//-/g')
 cd ${JEDI_STACK_ROOT}/${PKGDIR:-"pkg"}
 
 software=$name-$version
-url=http://www.zlib.net/$software.tar.gz
+url=https://www.zlib.net/$software.tar.gz
 [[ -d $software ]] || ( rm -f $software.tar.gz; $WGET $url; tar -xf $software.tar.gz )
 [[ ${DOWNLOAD_ONLY} =~ [yYtT] ]] && exit 0
 
diff --git a/modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua b/modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua
new file mode 100644
index 0000000..48877e5
--- /dev/null
+++ b/modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua
@@ -0,0 +1,35 @@
+help([[
+]])
+
+local pkgName    = myModuleName()
+local pkgVersion = myModuleVersion()
+local pkgNameVer = myModuleFullName()
+
+local hierA        = hierarchyA(pkgNameVer,1)
+local compNameVer  = hierA[1]
+local compNameVerD = compNameVer:gsub("/","-")
+
+--io.stderr:write("compNameVer: ",compNameVer,"\n")
+--io.stderr:write("compNameVerD: ",compNameVerD,"\n")
+
+family("mpi")
+
+conflict(pkgName)
+conflict("mpich","openmpi")
+
+always_load("intel/2020u4")
+prereq("intel/2020u4")
+
+try_load("szip")
+
+local opt = os.getenv("JEDI_OPT") or os.getenv("OPT") or "/opt/modules"
+--local base = "/opt/intel17/compilers_and_libraries_2017.1.132"
+local base = "/share/apps/compute/intel/intelmpi2020u4/compilers_and_libraries_2020"
+
+setenv("I_MPI_ROOT", pathJoin(base,"linux/mpi"))
+setenv("MPI_ROOT", pathJoin(base,"linux/mpi"))
+
+whatis("Name: ".. pkgName)
+whatis("Version: " .. pkgVersion)
+whatis("Category: library")
+whatis("Description: Intel MPI library")
diff --git a/modulefiles/compiler/compilerName/compilerVersion/jedi-intelmpi/jedi-intelmpi.lua b/modulefiles/compiler/compilerName/compilerVersion/jedi-intelmpi/jedi-intelmpi.lua
new file mode 100644
index 0000000..92758f8
--- /dev/null
+++ b/modulefiles/compiler/compilerName/compilerVersion/jedi-intelmpi/jedi-intelmpi.lua
@@ -0,0 +1,30 @@
+help([[
+]])
+
+local pkgName    = myModuleName()
+local pkgVersion = myModuleVersion()
+local pkgNameVer = myModuleFullName()
+
+local hierA        = hierarchyA(pkgNameVer,1)
+local compNameVer  = hierA[1]
+local compNameVerD = compNameVer:gsub("/","-")
+
+conflict(pkgName)
+conflict("jedi-openmpi","jedi-mpich")
+
+local mpi = pathJoin("intelmpi",pkgVersion)
+load(mpi)
+prereq(mpi)
+
+local opt = os.getenv("JEDI_OPT") or os.getenv("OPT") or "/opt/modules"
+local mpath = pathJoin(opt,"modulefiles/mpi",compNameVer,"intelmpi",pkgVersion)
+prepend_path("MODULEPATH", mpath)
+
+setenv("MPI_FC",  "mpiifort")
+setenv("MPI_CC",  "mpiicc")
+setenv("MPI_CXX", "mpiicpc")
+
+whatis("Name: ".. pkgName)
+whatis("Version: " .. pkgVersion)
+whatis("Category: library")
+whatis("Description: Intel MPI library and module access")
diff --git a/modulefiles/core/jedi-intel/jedi-intel.lua b/modulefiles/core/jedi-intel/jedi-intel.lua
index 33253b9..6ab1996 100644
--- a/modulefiles/core/jedi-intel/jedi-intel.lua
+++ b/modulefiles/core/jedi-intel/jedi-intel.lua
@@ -11,6 +11,8 @@ conflict(pkgName)
 conflict("jedi-gnu")
 
 local compiler = pathJoin("intel",pkgVersion)
+load("gnu/8.3.0")
+prereq("gnu/8.3.0")
 load(compiler)
 prereq(compiler)
 try_load("mkl")
-- 
2.19.5

EOL

cecho "Setting current directory in patch file..." |& tee -a "${CCONFIGURELOG}"
perl -pi -e "s|CHANGEME|${PWD%%/${PWD##*/}}/modules|" 0001-comet.patch  |& tee -a "${CCONFIGURELOG}"

cecho "Applying patch file..." |& tee -a "${CCONFIGURELOG}"
git am 0001-comet.patch  |& tee -a "${CCONFIGURELOG}"

cecho "Moving into buildscripts/ directory..." |& tee -a "${CCONFIGURELOG}"
cd buildscripts/ 

#CPAPADOP these have been added in the newer patch
#cecho "Applying additional fixes that did not make patch..." |& tee -a "${CCONFIGURELOG}"
## Didn't make the patch
#perl -pi -e 's/url=http:/url=https:/' libs/build_zlib.sh |& tee -a "${CCONFIGURELOG}"
#perl -pi -e 's/1.2.11/1.2.12/' build_stack.sh |& tee -a "${CCONFIGURELOG}"
#perl -pi -e 's/NTHREADS=4/NTHREADS=24/' config/config_custom.sh |& tee -a "${CCONFIGURELOG}"

cecho "Skipping ./setup_environment.sh step, we do not need it..." |& tee -a "${CCONFIGURELOG}"
# ./setup_environment.sh |& tee -a "${CCONFIGURELOG}"

cecho "Running ./setup_modules.sh custom..." |& tee -a "${CCONFIGURELOG}"
./setup_modules.sh custom >> "${CBUILDLOG}" 2>&1

ALLGOOD=`tail -4 "${CBUILDLOG}" |grep -c "setup_modules.sh custom: success"`

if [[ $ALLGOOD -eq 0 ]]
then
  cecho "ERROR: Did not get confirmation that the './setup_module.sh custom' completed successfully. Exiting..."
  exit 1
fi

cecho "Last few lines of the build log..." |& tee -a "${CCONFIGURELOG}"
/bin/tail "${CBUILDLOG}" |& tee -a "${CCONFIGURELOG}"

cecho "Running ./build_stack.sh custom (go get some coffee, then go for a long hike, and maybe when you get back it will be done)..." |& tee -a "${CCONFIGURELOG}"
./build_stack.sh custom >> "${CBUILDLOG}" 2>&1

ALLGOOD=`tail -4 "${CBUILDLOG}" |grep -c "build_stack.sh custom: success"`

if [[ $ALLGOOD -eq 0 ]]
then
  cecho "ERROR: Did not get confirmation that the './build_stack.sh custom' completed successfully. Letting this script finish, but it likely did not work..."
fi

cecho "Last few lines of the build log..." |& tee -a "${CCONFIGURELOG}"
/bin/tail "${CBUILDLOG}" |& tee -a "${CCONFIGURELOG}"
# If all goes well this will take a while, it is building everything

cecho "COMPLETED!!!" |& tee -a "${CCONFIGURELOG}"

cd ../.. 

cat > setup_environment.sh << 'EOL'
conda env list > /dev/null 2>&1
if [[ $? -ne 0 ]]
then
  source CHANGEMEPATH/miniconda3/bin/activate
  conda env list > /dev/null 2>&1
  if [[ $? -ne 0 ]]
  then
    echo "Could not find conda, and failed to load it from original setup folder. This won't work."
    exit 1
  fi
fi
conda activate CHANGEMEPATH/env
export JEDI_OPT=CHANGEMEPATH/modules
module use /share/apps/compute/modulefiles /share/apps/compute/modulefiles/applications $JEDI_OPT/modulefiles/core
module use -a ${JEDI_OPT}/modulefiles/mpi/intel/2020u4/intelmpi/2020u4
module use -a ${JEDI_OPT}/modulefiles/compiler/intel/2020u4


# ------------------------- core -------------------------
module load boost-headers/1.68.0
module load cmake/3.20.0
module load ecbuild/ecmwf-3.6.1
module load eigen/3.3.7
module load gsl_lite/0.37.0
module load jedi-intel/2020u4
module load json/3.9.1
module load pybind11/2.7.0

# ------------------------- mpi -------------------------
module load eckit/ecmwf-1.18.2
module load fckit/ecmwf-0.9.5
module load atlas/ecmwf-0.29.0
module load hdf5/1.12.0
module load netcdf/4.7.4
module load nccmp/1.8.7.0
module load pio/2.5.1-debug
module load pnetcdf/1.12.2

# ------------------------- compiler -------------------------
module load bufr/noaa-emc-11.5.0
module load eccodes/2.24.0
module load jedi-intelmpi/2020u4
module load json-schema-validator/2.1.0
module load lapack/3.8.0
module load szip/2.1.1
module load udunits/2.2.28
module load zlib/1.2.12


# fix the prompt
#. ~/.bashrc
EOL

perl -pi -e "s|CHANGEMEPATH|${PWD}|" setup_environment.sh  |& tee -a "${CCONFIGURELOG}"

chmod a+x setup_environment.sh |& tee -a "${CCONFIGURELOG}"

cecho "To setup the environment if you get logged out, just run: source ${PWD}/setup_environment.sh" |& tee -a "${CCONFIGURELOG}"

cecho "All output from this setup can be found in: ${CCONFIGURELOG}"

