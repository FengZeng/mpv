#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
MPV_DIR="$VENDOR_DIR/mpv"
MPV_VERSION="${MPV_VERSION:-0.41.0}"
VERSION_FILE="$MPV_DIR/.mpv-version"
TARBALL="$VENDOR_DIR/mpv-v${MPV_VERSION}.tar.gz"
SOURCE_URL="https://github.com/mpv-player/mpv/archive/refs/tags/v${MPV_VERSION}.tar.gz"

mkdir -p "$VENDOR_DIR"

if [ -f "$VERSION_FILE" ] && [ "$(cat "$VERSION_FILE")" = "$MPV_VERSION" ]; then
    echo "mpv v${MPV_VERSION} already exists at $MPV_DIR"
    exit 0
fi

apply_patch() {
    patch -p1 -N <<'PATCH'
diff --git a/vendor/mpv/video/out/vulkan/context_mac.m b/vendor/mpv/video/out/vulkan/context_mac.m
index 281a4bdf2f..21af6a39e4 100644
--- a/vendor/mpv/video/out/vulkan/context_mac.m
+++ b/vendor/mpv/video/out/vulkan/context_mac.m
@@ -15,7 +15,9 @@
  * License along with mpv.  If not, see <http://www.gnu.org/licenses/>.
  */

+#include "video/out/gpu/ra.h"
 #import <QuartzCore/QuartzCore.h>
+#include <stdint.h>

 #include "video/out/gpu/context.h"
 #include "osdep/mac/swift.h"
@@ -24,8 +26,17 @@
 #include "context.h"
 #include "utils.h"

+struct ExternalLayer {
+    CAMetalLayer *layer;
+    atomic_int w, h;
+    void *vo;
+    void* resize_callback;
+};
+
 struct priv {
     struct mpvk_ctx vk;
+    struct ExternalLayer *external_layer;
+    int width, height;
     MacCommon *vo_mac;
 };

@@ -35,19 +46,26 @@ static void mac_vk_uninit(struct ra_ctx *ctx)

     ra_vk_ctx_uninit(ctx);
     mpvk_uninit(&p->vk);
-    [p->vo_mac uninit:ctx->vo];
+    if (p->vo_mac)
+        [p->vo_mac uninit:ctx->vo];
 }

 static void mac_vk_swap_buffers(struct ra_ctx *ctx)
 {
     struct priv *p = ctx->priv;
-    [p->vo_mac swapBuffer];
+    if (p->vo_mac)
+        [p->vo_mac swapBuffer];
 }

 static void mac_vk_get_vsync(struct ra_ctx *ctx, struct vo_vsync_info *info)
 {
     struct priv *p = ctx->priv;
-    [p->vo_mac fillVsyncWithInfo:info];
+    if (p->vo_mac)
+        [p->vo_mac fillVsyncWithInfo:info];
+}
+
+static void resize_callback(void* vo) {
+    vo_wakeup(vo);
 }

 static int mac_vk_color_depth(struct ra_ctx *ctx)
@@ -58,13 +76,17 @@ static int mac_vk_color_depth(struct ra_ctx *ctx)
 static bool mac_vk_check_visible(struct ra_ctx *ctx)
 {
     struct priv *p = ctx->priv;
-    return [p->vo_mac isVisible];
+    if (p->vo_mac)
+        return [p->vo_mac isVisible];
+    else
+        return true;
 }

 static bool mac_vk_init(struct ra_ctx *ctx)
 {
     struct priv *p = ctx->priv = talloc_zero(ctx, struct priv);
     struct mpvk_ctx *vk = &p->vk;
+    const CAMetalLayer* metal_layer = NULL;
     int msgl = ctx->opts.probing ? MSGL_V : MSGL_ERR;

     if (!NSApp) {
@@ -75,15 +97,32 @@ static bool mac_vk_init(struct ra_ctx *ctx)
     if (!mpvk_init(vk, ctx, VK_EXT_METAL_SURFACE_EXTENSION_NAME))
         goto error;

-    p->vo_mac = [[MacCommon alloc] init:ctx->vo];
-    if (!p->vo_mac)
-        goto error;
+
+    if (ctx->vo->opts->WinID > 0) {
+        p->external_layer = (struct ExternalLayer *)(uintptr_t)ctx->vo->opts->WinID;
+        p->width = 0;
+        p->height = 0;
+        p->vo_mac = NULL;
+        metal_layer = p->external_layer->layer;
+        p->external_layer->vo = ctx->vo;
+        p->external_layer->resize_callback = resize_callback;
+        MP_WARN(ctx, "external layer: %p\n", p->external_layer);
+        MP_WARN(ctx,
+               "Using external Metal layer, make sure it is configured correctly.\n"
+               "layer: %p,Width: %d, Height: %d\n", p->external_layer->layer, p->external_layer->w, p->external_layer->h);
+    } else {
+        p->external_layer = NULL;
+        p->vo_mac = [[MacCommon alloc] init:ctx->vo];
+        if (!p->vo_mac)
+            goto error;
+        metal_layer = p->vo_mac.layer;
+    }

     VkMetalSurfaceCreateInfoEXT mac_info = {
         .sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT,
         .pNext = NULL,
         .flags = 0,
-        .pLayer = p->vo_mac.layer,
+        .pLayer = metal_layer,
     };

     struct ra_ctx_params params = {
@@ -125,15 +164,36 @@ static bool resize(struct ra_ctx *ctx)
 static bool mac_vk_reconfig(struct ra_ctx *ctx)
 {
     struct priv *p = ctx->priv;
-    if (![p->vo_mac config:ctx->vo])
+    if (p->vo_mac && ![p->vo_mac config:ctx->vo])
         return false;
+    if (p->external_layer) {
+        if (ctx->vo->dwidth != p->width || ctx->vo->dheight != p->height) {
+            ctx->vo->dwidth = p->width ;
+            ctx->vo->dheight = p->height;
+        }
+    }
     return true;
 }

 static int mac_vk_control(struct ra_ctx *ctx, int *events, int request, void *arg)
 {
     struct priv *p = ctx->priv;
-    int ret = [p->vo_mac control:ctx->vo events:events request:request data:arg];
+    int ret = 0;
+    if (p->vo_mac)
+        ret = [p->vo_mac control:ctx->vo events:events request:request data:arg];
+
+    if (p->external_layer) {
+        if (p->width != p->external_layer->w || p->height != p->external_layer->h) {
+            MP_WARN(ctx, "External layer size changed: %dx%d -> %dx%d\n",
+                    p->width, p->height,
+                    p->external_layer->w, p->external_layer->h);
+            p->width = p->external_layer->w ;
+            p->height = p->external_layer->h;
+            *events |= VO_EVENT_RESIZE;
+            *events |= VO_EVENT_EXPOSE;
+            return ra_vk_ctx_resize(ctx, p->width, p->height);
+        }
+    }

     if (*events & VO_EVENT_RESIZE) {
         if (!resize(ctx))
PATCH
}

echo "Downloading mpv v${MPV_VERSION}..."
rm -rf "$MPV_DIR"
mkdir -p "$MPV_DIR"
curl --fail --location --retry 3 --retry-delay 2 --output "$TARBALL" "$SOURCE_URL"
tar -zxf "$TARBALL" -C "$MPV_DIR" --strip-components=1 && apply_patch
echo "$MPV_VERSION" > "$VERSION_FILE"
rm -f "$TARBALL"
echo "Done: $MPV_DIR"
