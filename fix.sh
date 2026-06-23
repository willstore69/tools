#!/data/data/com.termux/files/usr/bin/sh
set -eu

log() { printf '%s\n' "[AIO-FIX] $*"; }
warn() { printf '%s\n' "[AIO-FIX] WARNING: $*"; }

PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

log "Install/check compiler + Android stubs Termux..."
pkg update -y
pkg install -y clang lld binutils make cmake ninja patchelf libandroid-stub ndk-sysroot ndk-multilib ndk-multilib-native-stubs ndk-multilib-native-static

log "Bersihkan env NDK/CC yang sering menunjuk ke NDK linux-x86_64..."
unset AIO_NDK_ROOT || true
unset ANDROID_NDK_HOME || true
unset ANDROID_NDK_ROOT || true
unset NDK_HOME || true
unset NDK_ROOT || true
unset CC || true
unset CXX || true

for d in "$HOME_DIR/android-ndk-r28" "$HOME_DIR/android-ndk-r27" "$HOME_DIR/android-ndk-r26d" "$HOME_DIR/android-ndk" "$HOME_DIR/ndk"; do
  if [ -d "$d/toolchains/llvm/prebuilt/linux-x86_64" ]; then
    base_name=$(basename "$d")
    target="$HOME_DIR/disabled-${base_name}-linux-x86_64"
    n=1
    while [ -e "$target" ]; do
      target="$HOME_DIR/disabled-${base_name}-linux-x86_64-$n"
      n=$((n + 1))
    done
    log "Rename NDK PC agar tidak auto-terpilih: $d -> $target"
    mv "$d" "$target"
  fi
done

for d in "$HOME_DIR"/android-ndk*_linux_x86_64_OFF "$HOME_DIR"/android-ndk*_OFF; do
  if [ -d "$d" ]; then
    base_name=$(basename "$d")
    target="$HOME_DIR/disabled-${base_name}"
    n=1
    while [ -e "$target" ]; do
      target="$HOME_DIR/disabled-${base_name}-$n"
      n=$((n + 1))
    done
    log "Rename sisa NDK OFF yang masih diawali android-ndk: $d -> $target"
    mv "$d" "$target"
  fi
done

log "Hapus export NDK lama dari shell rc kalau ada..."
for rc in "$HOME_DIR/.bashrc" "$HOME_DIR/.zshrc" "$HOME_DIR/.profile"; do
  if [ -f "$rc" ]; then
    sed -i '/ANDROID_NDK/d;/AIO_NDK/d;/NDK_ROOT/d;/NDK_HOME/d;/export CC=/d;/export CXX=/d' "$rc" || true
  fi
done

log "Cek file stub yang dibutuhkan..."
missing=0
for p in "$PREFIX_DIR/lib/libandroid.so" "$PREFIX_DIR/aarch64-linux-android/lib/liblog.so" "$PREFIX_DIR/opt/ndk-multilib/aarch64-linux-android/lib/liblog.so"; do
  if [ -e "$p" ]; then
    log "OK: $p"
  else
    warn "Belum ada: $p"
    missing=1
  fi
done

log "Tes compile arm64 Dex2C/Standard minimal..."
tmp_so="${TMPDIR:-/tmp}/aio_std_arm64_test.so"
if clang --target=aarch64-linux-android23 -fPIC -shared \
  -L"$PREFIX_DIR/aarch64-linux-android/lib" \
  -L"$PREFIX_DIR/opt/ndk-multilib/aarch64-linux-android/lib" \
  -L"$PREFIX_DIR/lib" \
  -Wl,-rpath-link,"$PREFIX_DIR/aarch64-linux-android/lib" \
  -Wl,-rpath-link,"$PREFIX_DIR/opt/ndk-multilib/aarch64-linux-android/lib" \
  -Wl,-rpath-link,"$PREFIX_DIR/lib" \
  -x c - -o "$tmp_so" -llog -landroid -ldl -lz <<'EOF'
#include <android/log.h>
int aio_std_test(void) { return __android_log_write(4, "AIO", "ok"); }
EOF
then
  file "$tmp_so" || true
  log "SUKSES: toolchain Standard/Dex2C arm64 siap."
else
  warn "Tes compile gagal. Install ulang paket stub lalu coba lagi."
  exit 1
fi

if [ "$missing" -ne 0 ]; then
  warn "Ada stub yang masih hilang, cek repo Termux/mirror kalau compile tetap gagal."
fi

log "Selesai. Tutup-buka Termux atau jalankan ulang aio-mod.py dari shell ini."
