#!/bin/bash
set -e

# Parse command-line arguments
for arg in "$@"
do
  case $arg in
    --arch=*)
      ARCH="${arg#*=}"
      shift
      ;;
    --ptx=*)
      PTX="${arg#*=}"
      shift
      ;;
    *)
      echo "Unknown option $arg"
      exit 1
      ;;
  esac
done

install_opencv () {

  # Define CUDA architecture flags (adjust based on your GPU)
  if [ -z "$ARCH" ]; then
    echo "Error: --arch must be provided."
    echo "Usage: ./OpenCV-4-10-0-tracking.sh --arch=6.1 [--ptx=6.1]"
    exit 1
  fi

  if [ -z "$PTX" ]; then
    PTX=$ARCH
  fi

  echo "Installing OpenCV 4.10.0 with CUDA support"
  echo "This may take a while depending on system resources..."

  # Detect number of cores
  NO_JOB=$(nproc)
  
  echo "Installing OpenCV 4.10.0"
  echo "It will take 3.5 hours !"
  
  # install the some dependencies first
  sudo apt-get install -y build-essential git unzip pkg-config zlib1g-dev
  sudo apt-get install -y python3-dev python3-numpy
  sudo apt-get install -y gstreamer1.0-tools libgstreamer-plugins-base1.0-dev
  sudo apt-get install -y libgstreamer-plugins-good1.0-dev
  sudo apt-get install -y libtbb2 libgtk-3-dev libxine2-dev
  
  if [ -f /etc/os-release ]; then
      # Source the /etc/os-release file to get variables
      . /etc/os-release
      # Extract the major version number from VERSION_ID
      VERSION_MAJOR=$(echo "$VERSION_ID" | cut -d'.' -f1)
      # Check if the extracted major version is 22 or earlier
      if [ "$VERSION_MAJOR" = "22" ]; then
          sudo apt-get install -y libswresample-dev libdc1394-dev
      else
	  sudo apt-get install -y libavresample-dev libdc1394-22-dev
      fi
  else
      sudo apt-get install -y libavresample-dev libdc1394-22-dev
  fi

  # install the common dependencies
  sudo apt-get install -y cmake
  sudo apt-get install -y libjpeg-dev libjpeg8-dev libjpeg-turbo8-dev
  sudo apt-get install -y libpng-dev libtiff-dev libglew-dev
  sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev
  sudo apt-get install -y libgtk2.0-dev libgtk-3-dev libcanberra-gtk*
  sudo apt-get install -y python3-pip
  sudo apt-get install -y libxvidcore-dev libx264-dev
  sudo apt-get install -y libtbb-dev libxine2-dev
  sudo apt-get install -y libv4l-dev v4l-utils qv4l2
  sudo apt-get install -y libtesseract-dev libpostproc-dev
  sudo apt-get install -y libvorbis-dev
  sudo apt-get install -y libfaac-dev libmp3lame-dev libtheora-dev
  sudo apt-get install -y libopencore-amrnb-dev libopencore-amrwb-dev
  sudo apt-get install -y libopenblas-dev libatlas-base-dev libblas-dev
  sudo apt-get install -y liblapack-dev liblapacke-dev libeigen3-dev gfortran
  sudo apt-get install -y libhdf5-dev libprotobuf-dev protobuf-compiler
  sudo apt-get install -y libgoogle-glog-dev libgflags-dev
  sudo apt-get install -y libtbb-dev # for installing on x86_64
 
  # remove old versions or previous builds
  cd ~ 
  sudo rm -rf opencv*
  # download the 4.10.0 version
  wget -O opencv.zip https://github.com/opencv/opencv/archive/4.10.0.zip 
  # unpack
  unzip opencv.zip 
  
  # Some administration to make life easier later on
  mv opencv-4.10.0 opencv
  
  # clean up the zip files
  rm opencv.zip

  # If building in container on Jetson Nano with r32.7.1 base container then need this fix
  # for tuple missing error
  if [ -f /.dockerenv ]; then
    echo "Running inside Docker: Cloning latest opencv_contrib 4.x branch for CUDA tuple fix"
    git clone --branch 4.x https://github.com/opencv/opencv_contrib.git
  else
    echo "Running on host system"
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.10.0.zip 
    unzip opencv_contrib.zip
    mv opencv_contrib-4.10.0 opencv_contrib
    rm opencv_contrib.zip
  fi

  # set install dir
  cd ~/opencv
  mkdir build
  cd build
  
  # run cmake
  cmake -D CMAKE_BUILD_TYPE=RELEASE \
  cmake -D CMAKE_INSTALL_PREFIX=/usr \
  -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
  -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 \
  -D WITH_OPENCL=OFF \
  -D CUDA_ARCH_BIN=${ARCH} \
  -D CUDA_ARCH_PTX=${PTX} \
  -D WITH_CUDA=ON \
  -D WITH_CUDNN=ON \
  -D WITH_CUBLAS=ON \
  -D ENABLE_FAST_MATH=ON \
  -D CUDA_FAST_MATH=ON \
  -D OPENCV_DNN_CUDA=ON \
  -D WITH_QT=OFF \
  -D WITH_OPENMP=ON \
  -D BUILD_TIFF=ON \
  -D WITH_FFMPEG=ON \
  -D WITH_GSTREAMER=ON \
  -D WITH_GSTREAMER_1_0=ON \
  -D WITH_TBB=ON \
  -D BUILD_TBB=OFF \
  -D BUILD_TESTS=OFF \
  -D WITH_EIGEN=ON \
  -D WITH_V4L=ON \
  -D WITH_LIBV4L=ON \
  -D WITH_PROTOBUF=ON \
  -D OPENCV_ENABLE_NONFREE=ON \
  -D INSTALL_C_EXAMPLES=OFF \
  -D INSTALL_PYTHON_EXAMPLES=OFF \
  -D PYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages \
  -D OPENCV_GENERATE_PKGCONFIG=ON \
  -D BUILD_EXAMPLES=OFF \
  -D CMAKE_CXX_FLAGS="-march=native -mtune=native" \
  -D CMAKE_C_FLAGS="-march=native -mtune=native" \
  -D BUILD_opencv_tracking=ON ..

  make -j ${NO_JOB} 
  
  directory="/usr/include/opencv4/opencv2"
  if [ -d "$directory" ]; then
    # Directory exists, so delete it
    sudo rm -rf "$directory"
  fi
  
  sudo make install
  sudo ldconfig
  
  # cleaning (frees 320 MB)
  make clean
  sudo apt-get update
  
  echo "Congratulations!"
  echo "You've successfully installed OpenCV 4.10.0"
}

cd ~

if [ -d ~/opencv/build ]; then
  echo " "
  echo "You have a directory ~/opencv/build on your disk."
  echo "Continuing the installation will replace this folder."
  echo " "
  
  printf "Do you wish to continue (Y/n)?"
  read answer

  if [ "$answer" != "${answer#[Nn]}" ] ;then 
      echo "Leaving without installing OpenCV"
  else
      install_opencv
  fi
else
    install_opencv
fi