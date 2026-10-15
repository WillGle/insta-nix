{ antigravity-ide, stdenv, fetchurl, nodejs_22, lib }:
let
  nodeAddonApi = fetchurl {
    url = "https://registry.npmjs.org/node-addon-api/-/node-addon-api-7.1.1.tgz";
    hash = "sha256-sQRV0VqXfAzRehyw62eeA9k5+O+NQwLrM+H3jazHH4I=";
  };

  watcher = stdenv.mkDerivation {
    pname = "antigravity-parcel-watcher";
    version = "2.5.1";
    src = fetchurl {
      url = "https://github.com/parcel-bundler/watcher/archive/refs/tags/v2.5.1.tar.gz";
      hash = "sha256-i7J+zv7+uIturFNY1VSpOpMuSuhRjxl1nINsnAP9ueo=";
    };
    patches = [ ./parcel-watcher-exit.patch ];

    # Node-API v8 is supported by the bundled Node 22 runtime.
    buildPhase = ''
      runHook preBuild
      mkdir node-addon-api
      tar -xzf ${nodeAddonApi} -C node-addon-api --strip-components=1
      $CXX -std=c++17 -O2 -shared -fPIC -pthread \
        -DNAPI_VERSION=8 -DNAPI_DISABLE_CPP_EXCEPTIONS \
        -DNODE_GYP_MODULE_NAME=watcher -DWATCHMAN -DINOTIFY -DBRUTE_FORCE \
        -I${lib.getDev nodejs_22}/include/node -Inode-addon-api \
        src/binding.cc src/Watcher.cc src/Backend.cc src/DirTree.cc \
        src/Glob.cc src/Debounce.cc src/watchman/BSER.cc \
        src/watchman/WatchmanBackend.cc src/shared/BruteForceBackend.cc \
        src/linux/InotifyBackend.cc src/unix/legacy.cc \
        -o watcher.node
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 watcher.node $out/lib/watcher.node
      runHook postInstall
    '';
  };
in
antigravity-ide.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    watcherDir="$out/lib/antigravity-ide/resources/app/node_modules/@parcel/watcher"
    # Fail on a bundled dependency update rather than silently replacing a new version.
    test "$(jq -r .version "$watcherDir/package.json")" = "2.5.1"
    cp ${watcher}/lib/watcher.node "$watcherDir/build/Release/watcher.node"
  '';
})
