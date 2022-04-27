#!/bin/bash

# You can change these, but this is what I built against and know works on Comet.
export JEDISTACKREPO="https://github.com/JCSDA/jedi-stack.git"
export JEDISTACKBRANCH="develop"
export JEDISTACKCOMMIT="8753d606a00dd4ce29b95b6ce0e43fc5f66169c4"

export CCONFIGURELOG="${PWD}/comet-jedi-stack.`/bin/date -Iseconds`.log"
export CBUILDLOG="${PWD}/comet-jedi-stack-builds.`/bin/date -Iseconds`.log"


ECHO='echo -e \n##'
ECHON='echo -e ##'

$ECHO "Writing the following logs:" |& tee -a "${CCONFIGURELOG}"
$ECHON " Log of what you see on the screen: ${CCONFIGURELOG}" |& tee -a "${CCONFIGURELOG}"
$ECHON " Log of the verbose build output (hidden): ${CBUILDLOG}" |& tee -a "${CCONFIGURELOG}"

# For downloads
export ftp_proxy=10.21.2.4:3128

if [[ `hostname|sed 's/\..*//'|egrep -c 'comet-..-..'` -ne 1 ]]
then
  $ECHO " Has to be run on a compute node, use the following command to launch an interactive session:" |& tee -a "${CCONFIGURELOG}"
  echo "$ srun --partition=compute --pty --nodes=1 --wait=0 --export=ALL -t 48:00:00 /bin/bash" |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

$ECHO "Purging any modules to remove conflicts..." |& tee -a "${CCONFIGURELOG}"
eval `/usr/bin/modulecmd bash purge` |& tee -a "${CCONFIGURELOG}"
unset LD_LIBRARY_PATH


$ECHO "Moving up one directory..." |& tee -a "${CCONFIGURELOG}"
cd .. 
$ECHO "Working in ${PWD}..." |& tee -a "${CCONFIGURELOG}"

which conda > /dev/null 2>&1
if [[ $? -eq 1 ]]
then
  $ECHO "This setup requires Conda, installing Miniconda in this directory..." |& tee -a "${CCONFIGURELOG}"

  # Set by default and upsets the install
  unset PYTHONPATH

  $ECHON " -Downloading..." |& tee -a "${CCONFIGURELOG}"
  /bin/wget -nv https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh |& tee -a "${CCONFIGURELOG}"
  $ECHON " -Installing (takes a few minutes)... $(/bin/date)" |& tee -a "${CCONFIGURELOG}"
  /bin/bash Miniconda3-latest-Linux-x86_64.sh -b -p `pwd`/miniconda3 >> "${CCONFIGURELOG}" 2>&1

  $ECHON " -Activating environment" |& tee -a "${CCONFIGURELOG}"
  source ./miniconda3/bin/activate 
  $ECHON " -Confirming it is active" |& tee -a "${CCONFIGURELOG}"
  conda env list > /dev/null 2>&1
  if [[ $? -ne 0 ]]
  then
    $ECHON " -ERROR! Failed to get exit code zero when we ran... conda env list" |& tee -a "${CCONFIGURELOG}"
    exit 1
  fi
  $ECHON " -Done and looks like it is working!" |& tee -a "${CCONFIGURELOG}"
else
  CCONDAROOT=${CONDA_EXE%%/conda}
  if [ ! -f "${CCONDAROOT}/activate" ]
  then
    $ECHON "ERROR! Failed find 'bin/activate' file to source for current conda environment: ${CCONDAROOT}" |& tee -a "${CCONFIGURELOG}"
    exit 1
  fi
  $ECHO "Sourcing ${CCONDAROOT}/activate so conda works properly..." |& tee -a "${CCONFIGURELOG}"

  source "${CCONDAROOT}/activate"
fi

if [[ -d ~/.lmod.d ]] 
then 
  $ECHO "Removing any lmod cache (causes issues)..." |& tee -a "${CCONFIGURELOG}"
  rm -rfv ~/.lmod.d |& tee -a "${CCONFIGURELOG}"
fi

$ECHO "Creating minimal conda environment in `pwd`/env" |& tee -a "${CCONFIGURELOG}"
conda create -y  -p ${PWD}/env >> "${CCONFIGURELOG}" 2>&1
$ECHO "Activating new environment..." |& tee -a "${CCONFIGURELOG}"
conda activate ${PWD}/env >> "${CCONFIGURELOG}" 2>&1

if [[ "x${CONDA_PREFIX}" != "x${PWD}/env" ]]
then
  $ECHO "ERROR! Not in the expected environment..." |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

$ECHO "Installing lmod & python..." |& tee -a "${CCONFIGURELOG}"
conda install -y -c conda-forge lmod python==3.9.12 >> "${CCONFIGURELOG}" 2>&1

$ECHO "Setting JEDI_OPT variable to ${PWD}/modules..." |& tee -a "${CCONFIGURELOG}"
export JEDI_OPT=${PWD}/modules 

$ECHO "Adding ${JEDI_OPT}/core, /share/apps/compute/modulefiles/applications, & /share/apps/compute/modulefiles/ to module search path" |& tee -a "${CCONFIGURELOG}"
module use /share/apps/compute/modulefiles /share/apps/compute/modulefiles/applications $JEDI_OPT/modulefiles/core 

$ECHO "Logging the available modules..." |& tee -a "${CCONFIGURELOG}"
module avail >> "${CCONFIGURELOG}" 2>&1

if [[ `module avail |& grep -c "intel/2019.5.281"` -ne 1 ]]
then
  $ECHO "ERROR! Did not find intel/2019.5.281 in list of modules..." |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

if [[ `module avail |& grep -c "intelmpi/2019.5.281"` -ne 1 ]]
then
  $ECHO "ERROR! Did not find intelmpi/2019.5.281 in list of modules..." |& tee -a "${CCONFIGURELOG}"
  exit 1
fi

$ECHO "Cloning jedi-stack repo from  ${JEDISTACKREPO}..." |& tee -a "${CCONFIGURELOG}"
git clone ${JEDISTACKREPO} |& tee -a "${CCONFIGURELOG}"

$ECHO "Moving into jedi-stack directory..." |& tee -a "${CCONFIGURELOG}"
cd jedi-stack 

$ECHO "Checking out ${JEDISTACKBRANCH} branch..." |& tee -a "${CCONFIGURELOG}"
git checkout ${JEDISTACKBRANCH} |& tee -a "${CCONFIGURELOG}"

$ECHO "Checking out ${JEDISTACKCOMMIT} commit..." |& tee -a "${CCONFIGURELOG}"
git checkout ${JEDISTACKCOMMIT} |& tee -a "${CCONFIGURELOG}"

$ECHO "Creating patch file (0001-comet.patch)..." |& tee -a "${CCONFIGURELOG}"
cat > 0001-comet.patch << 'EOL'
From f43ff5b9a5e23ee0bf4cb2f81bbcefdd0b08248b Mon Sep 17 00:00:00 2001
From: Patrick Mulrooney <mulroony@comet-33-03.sdsc.edu>
Date: Tue, 26 Apr 2022 18:26:13 -0700
Subject: [PATCH] CometChanges

---
 buildscripts/build_stack.sh                   |  2 +-
 buildscripts/config/config_custom.sh          | 86 +++++++++++++++++--
 .../compilerVersion/intelmpi/intelmpi.lua     | 35 ++++++++
 .../jedi-intelmpi/jedi-intelmpi.lua           | 30 +++++++
 4 files changed, 146 insertions(+), 7 deletions(-)
 create mode 100644 modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua
 create mode 100644 modulefiles/compiler/compilerName/compilerVersion/jedi-intelmpi/jedi-intelmpi.lua

diff --git a/buildscripts/build_stack.sh b/buildscripts/build_stack.sh
index 56ed809..5657dba 100755
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
index 757808c..622a585 100644
--- a/buildscripts/config/config_custom.sh
+++ b/buildscripts/config/config_custom.sh
@@ -5,8 +5,8 @@
 
 
 # Compiler/MPI combination
-export JEDI_COMPILER="gnu/9.3.0"
-export JEDI_MPI="openmpi/4.0.3"
+export JEDI_COMPILER="intel/2019.5.281"
+export JEDI_MPI="intelmpi/2019.5.281"
 #export MPI="mpich/3.2.1"
 
 #export JEDI_COMPILER="intel/19.0.5"
@@ -22,11 +22,12 @@ export JEDI_MPI="openmpi/4.0.3"
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
@@ -42,3 +43,76 @@ export FFLAGS=""
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
diff --git a/modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua b/modulefiles/compiler/compilerName/compilerVersion/intelmpi/intelmpi.lua
new file mode 100644
index 0000000..a8c265c
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
+always_load("intel/2019.5.281")
+prereq("intel/2019.5.281")
+
+try_load("szip")
+
+local opt = os.getenv("JEDI_OPT") or os.getenv("OPT") or "/opt/modules"
+--local base = "/opt/intel17/compilers_and_libraries_2017.1.132"
+local base = "/share/apps/compute/intel/intelmpi2019/compilers_and_libraries_2019"
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
-- 
2.19.5
EOL

$ECHO "Setting current directory in patch file..." |& tee -a "${CCONFIGURELOG}"
perl -pi -e "s|CHANGEME|${PWD%%/${PWD##*/}}/modules|" 0001-comet.patch  |& tee -a "${CCONFIGURELOG}"

$ECHO "Applying patch file..." |& tee -a "${CCONFIGURELOG}"
git am 0001-comet.patch  |& tee -a "${CCONFIGURELOG}"

$ECHO "Moving into buildscripts/ directory..." |& tee -a "${CCONFIGURELOG}"
cd buildscripts/ 

$ECHO "Applying additional fixes that did not make patch..." |& tee -a "${CCONFIGURELOG}"
# Didn't make the patch
perl -pi -e 's/url=http:/url=https:/' libs/build_zlib.sh |& tee -a "${CCONFIGURELOG}"
perl -pi -e 's/1.2.11/1.2.12/' build_stack.sh |& tee -a "${CCONFIGURELOG}"
perl -pi -e 's/NTHREADS=4/NTHREADS=24/' config/config_custom.sh |& tee -a "${CCONFIGURELOG}"

$ECHO "Skipping ./setup_environment.sh step, we do not need it..." |& tee -a "${CCONFIGURELOG}"
# ./setup_environment.sh |& tee -a "${CCONFIGURELOG}"

$ECHO "Running ./setup_modules.sh custom..." |& tee -a "${CCONFIGURELOG}"
./setup_modules.sh custom >> "${CBUILDLOG}" 2>&1
$ECHO "Last few lines of the build log..." |& tee -a "${CCONFIGURELOG}"
/bin/tail "${CBUILDLOG}" |& tee -a "${CCONFIGURELOG}"

$ECHO "Running ./build_stack.sh custom (go get some coffee, then go for a long hike, and maybe when you get back it will be done)..." |& tee -a "${CCONFIGURELOG}"
./build_stack.sh custom >> "${CBUILDLOG}" 2>&1
$ECHO "Last few lines of the build log..." |& tee -a "${CCONFIGURELOG}"
/bin/tail "${CBUILDLOG}" |& tee -a "${CCONFIGURELOG}"
# If all goes well this will take a while, it is building everything

$ECHO "COMPLETED!!!" |& tee -a "${CCONFIGURELOG}"

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
EOL

perl -pi -e "s|CHANGEMEPATH|${PWD}|" setup_environment.sh  |& tee -a "${CCONFIGURELOG}"

chmod a+x setup_environment.sh |& tee -a "${CCONFIGURELOG}"

$ECHO "To setup the environment if you get logged out, just run: ${PWD}/setup_environment.sh" |& tee -a "${CCONFIGURELOG}"

$ECHO "All output from this setup can be found in: ${CCONFIGURELOG}"

