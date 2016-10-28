ECWJP2_SDK = "/Hexagon/ERDASEcwJpeg2000SDK5.3.0/Desktop_Read-Only"

class EcwJp2Sdk < Requirement
  fatal true
  satisfy(:build_env => false) { File.exist? ECWJP2_SDK }

  def message; <<-EOS.undent
    ERDAS ECW/JP2 SDK was not found at:
      #{ECWJP2_SDK}

    Download SDK and install 'Desktop Read-Only' to default location from:
      http://download.intergraph.com/?ProductName=ERDAS%20ECW/JPEG2000%20SDK
    Installation may notify of failure when package scripts are being run,
    but the driver will still likely build.
  EOS
  end
end

class Gdal2Ecwjp2 < Formula
  homepage "http://www.gdal.org/frmt_ecw.html"
  url "http://download.osgeo.org/gdal/2.1.1/gdal-2.1.1.tar.gz"
  sha256 "55fc6ffbe76e9d2e7e6cf637010e5d4bba6a966d065f40194ff798544198236b"

  depends_on :macos => :lion # as per SDK docs
  depends_on EcwJp2Sdk
  depends_on "gdal2"

  def gdal_clib
    gdal_lib = "#{Formula["gdal2"].opt_lib}/libgdal.dylib"
    (%x[otool -L #{gdal_lib}].include? "libstdc++") ? "std" : ""
  end

  def install
    gdal = Formula["gdal2"]
    (lib/"gdal2plugins").mkpath

    # vendor Desktop Read-Only lib, etc
    # match c-lib that gdal was built against
    cp "#{ECWJP2_SDK}/lib/lib#{gdal_clib}c++/dynamic/libNCSEcw.dylib", "#{lib}/"
    system "install_name_tool", "-id", HOMEBREW_PREFIX/"lib/libNCSEcw.dylib", lib/"libNCSEcw.dylib"
    cp_r "#{ECWJP2_SDK}/etc", "#{prefix}/"

    # cxx flags
    args = %W[-Iport -Igcore -Ifrmts -DFRMT_ecw -DECWSDK_VERSION=51 -Ifrmts/ecw
              -I#{ECWJP2_SDK}/include -I#{ECWJP2_SDK}/include/NCSEcw/API
              -I#{ECWJP2_SDK}/include/NCSEcw/ECW -I#{ECWJP2_SDK}/include/NCSEcw/JP2]

    # source files
    Dir["frmts/ecw/*.cpp"].each do |src|
      args.concat %W[#{src}]
    end

    # plugin dylib
    args.concat %W[
      -dynamiclib
      -install_name #{HOMEBREW_PREFIX}/lib/gdal2plugins/gdal_ECW_JP2ECW.dylib
      -current_version #{version}
      -compatibility_version #{version}
      -o #{lib}/gdal2plugins/gdal_ECW_JP2ECW.dylib
      -undefined dynamic_lookup
    ]

    # ld flags
    args.concat %W[-L#{lib} -lNCSEcw]

    # build and install shared plugin
    system ENV.cxx, *args

  end

  def caveats; <<-EOS.undent
    This formula provides a plugin that allows GDAL or OGR to access geospatial
    data stored in its format. In order to use the shared plugin, you will need
    to set the following enviroment variable:

      export GDAL_DRIVER_PATH=#{HOMEBREW_PREFIX}/lib/gdal2plugins

    Once plugin is installed, the ERDAS ECW/JP2 SDK can be deleted from its
    default install location of:

      /Hexagon/ERDASEcwJpeg2000SDK*

  EOS
  end
end

