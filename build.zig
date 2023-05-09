const std = @import("std");

pub const SdlOptions = struct {
    ///The enabled video implementations
    video_implementations: EnabledSdlVideoImplementations = .{},
    ///The enabled joystick implementations
    joystick_implementations: EnabledSdlJoystickImplementations = .{},
    ///The thread implementation to use
    thread_implementation: SdlThreadImplementation = .generic,
    ///The power implementation to use
    power_implementation: ?SdlPowerImplementation = null,
    ///The thread implementation to use
    timer_implementation: SdlTimerImplementation = .dummy,
    ///The locale implementation to use
    locale_implementation: SdlLocaleImplementation = .dummy,
    ///The haptic implementation to use
    haptic_implementation: SdlHapticImplementation = .dummy,
    ///Whether or not to build SDL as a shared library
    shared: bool = false,
};

///Gets the default reccomended options for a particular CrossTarget
pub fn getDefaultOptionsForTarget(target: std.zig.CrossTarget) SdlOptions {
    var options = SdlOptions{};

    if (target.isLinux() or target.isFreeBSD() or target.isOpenBSD() or target.isNetBSD() or target.isDragonFlyBSD()) {
        //Linux, UNIX and BSD-likes all will have X11 and pthreads
        options.video_implementations.x11 = true;
        options.thread_implementation = .pthread;
        options.timer_implementation = .unix;
        options.locale_implementation = .unix;
    }

    if (target.isLinux()) {
        options.joystick_implementations.linux = true;
        options.joystick_implementations.steam = true;
        options.haptic_implementation = .linux;

        options.power_implementation = .linux;

        // Wayland is by-default on some modern distros, so lets compile it in by default too
        // temporarily commented out until linker errors are fixed
        // options.video_implementations.wayland = true;
    }

    if (target.isNetBSD() or target.isFreeBSD() or target.isOpenBSD() or target.isDragonFlyBSD()) {
        options.joystick_implementations.bsd = true;
    }

    if (target.isWindows()) {
        options.video_implementations.windows = true;

        //enable all 3 types of windows joystick input
        options.joystick_implementations.dinput = true;
        options.joystick_implementations.xinput = true;
        options.joystick_implementations.rawinput = true;

        options.thread_implementation = .windows;
        options.power_implementation = .windows;
        options.timer_implementation = .windows;
        options.locale_implementation = .windows;

        options.haptic_implementation = .windows;
    }

    if (target.isDarwin()) {
        options.thread_implementation = .pthread;
        options.power_implementation = .macosx;
        options.timer_implementation = .unix;
        options.locale_implementation = .macosx;

        options.joystick_implementations.apple = true;
        options.video_implementations.cocoa = true;
    }

    //Lets enable the dummy joystick implementation by default on all platforms
    options.joystick_implementations.dummy = true;

    return options;
}

//NOTE: these enum names must match the folder names!
const SdlThreadImplementation = enum {
    generic,
    n3ds,
    ngage,
    os2,
    ps2,
    psp,
    pthread,
    stdcpp,
    vita,
    windows,
};

//NOTE: these enum names must match the folder names!
const SdlPowerImplementation = enum {
    android,
    emscripten,
    haiku,
    linux,
    macosx,
    n3ds,
    psp,
    uikit,
    vita,
    windows,
    winrt,
};

//NOTE: these names must match the folder names!
const SdlHidApiImplementation = enum {
    android,
    ios,
    libusb,
    linux,
    mac,
    windows,
};

//NOTE: these names must match the folder names!
const SdlHapticImplementation = enum {
    android,
    darwin,
    dummy,
    linux,
    windows,
};

//NOTE: these names must match the folder names!
const SdlTimerImplementation = enum {
    dummy,
    haiku,
    n3ds,
    ngage,
    os2,
    ps2,
    psp,
    unix,
    vita,
    windows,
};

//NOTE: these names must match the folder names!
const SdlLocaleImplementation = enum {
    android,
    dummy,
    emscripten,
    haiku,
    macosx,
    n3ds,
    unix,
    vita,
    windows,
    winrt,
};

const EnabledSdlJoystickImplementations = struct {
    android: bool = false,
    apple: bool = false,
    bsd: bool = false,
    darwin: bool = false,
    dummy: bool = false,
    emscripten: bool = false,
    haiku: bool = false,
    hidapi: bool = false,
    iphoneos: bool = false,
    linux: bool = false,
    n3ds: bool = false,
    os2: bool = false,
    ps2: bool = false,
    psp: bool = false,
    steam: bool = false,
    virtual: bool = false,
    vita: bool = false,
    rawinput: bool = false,
    dinput: bool = false,
    xinput: bool = false,
    wgi: bool = false,
};

//NOTE: these names need to stay the same as the folders in src/video/
const EnabledSdlVideoImplementations = struct {
    android: bool = false,
    arm: bool = false,
    cocoa: bool = false,
    directfb: bool = false,
    dummy: bool = false,
    emscripten: bool = false,
    haiku: bool = false,
    khronos: bool = false,
    kmsdrm: bool = false,
    n3ds: bool = false,
    nacl: bool = false,
    ngage: bool = false,
    offscreen: bool = false,
    os2: bool = false,
    pandora: bool = false,
    ps2: bool = false,
    psp: bool = false,
    qnx: bool = false,
    raspberry: bool = false,
    riscos: bool = false,
    uikit: bool = false,
    vita: bool = false,
    vivante: bool = false,
    wayland: bool = false,
    windows: bool = false,
    winrt: bool = false,
    x11: bool = false,
};

//lazy toUpper implementation, only supports ASCII strings
pub fn lazyToUpper(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var upper = try allocator.alloc(u8, str.len);

    for (str, 0..str.len) |char, i| {
        if (str[i] > 0x7A or str[i] < 0x61) {
            upper[i] = char;
            continue;
        }

        upper[i] = char - 0x20;
    }

    return upper;
}

pub fn createSDL(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode, sdl_options: SdlOptions) !*std.build.CompileStep {
    const options = .{
        .name = "SDL2",
        .target = target,
        .optimize = optimize,
    };

    const lib = if (sdl_options.shared) b.addSharedLibrary(options) else b.addStaticLibrary(options);
    const t = lib.target_info.target;

    var c_flags = std.ArrayList([]const u8).init(b.allocator);

    try c_flags.append("-std=c99");

    //workaround some parsing issues in the macos system-sdk in use
    lib.defineCMacro("__kernel_ptr_semantics", "");

    switch (t.os.tag) {
        .linux => {
            try c_flags.appendSlice(&.{
                "-DSDL_INPUT_LINUXEV",
                "-DHAVE_LINUX_INPUT_H", //TODO: properly check for this like the CMake script does
            });
        },
        else => {},
    }

    lib.addIncludePath(root_path ++ "include");
    lib.addCSourceFiles(&generic_src_files, c_flags.items);
    lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", "1");

    lib.linkLibC();
    //TODO: we need to link LibCpp in some cases, like the libcpp thread implementation
    // lib.linkLibCpp();

    //Define the C macro enabling the correct timer implementation
    lib.defineCMacro(try std.mem.concat(b.allocator, u8, &.{ "SDL_TIMER_", try lazyToUpper(b.allocator, @tagName(sdl_options.timer_implementation)) }), "1");

    //Define the C macro enabling the correct thread implementation
    lib.defineCMacro(try std.mem.concat(b.allocator, u8, &.{ "SDL_THREAD_", try lazyToUpper(b.allocator, @tagName(sdl_options.thread_implementation)) }), "1");

    //Darwin is *special* and the define name doesnt match.
    if (sdl_options.haptic_implementation == .darwin) {
        lib.defineCMacro("SDL_HAPTIC_IOKIT", "1");
    } else if (sdl_options.haptic_implementation == .windows) {
        lib.defineCMacro("SDL_HAPTIC_DINPUT", "1");
        lib.defineCMacro("SDL_HAPTIC_XINPUT", "1");
    } else {
        //Define the C macro enabling the correct thread implementation
        lib.defineCMacro(try std.mem.concat(b.allocator, u8, &.{ "SDL_HAPTIC_", try lazyToUpper(b.allocator, @tagName(sdl_options.haptic_implementation)) }), "1");
    }

    const viStructInfo: std.builtin.Type.Struct = @typeInfo(EnabledSdlVideoImplementations).Struct;
    //Iterate over all fields on the video implementations struct
    inline for (viStructInfo.fields) |field| {
        var enabled: bool = @field(sdl_options.video_implementations, field.name);
        //If its enabled in the options
        if (enabled) {
            //they arent consistent with their naming always :/
            if (std.mem.eql(u8, field.name, "raspberry")) {
                lib.defineCMacro("SDL_VIDEO_DRIVER_RPI", "1");
            } else {
                //Make the macro name
                var name = try std.mem.concat(b.allocator, u8, &.{
                    "SDL_VIDEO_DRIVER_",
                    try lazyToUpper(b.allocator, field.name),
                });
                //Set the macro to 1
                lib.defineCMacro(name, "1");
                // std.debug.print("enabling video driver {s} from {s} upper {s}\n", .{ name, field.name, try lazyToUpper(b.allocator, field.name) });
            }
        }
    }

    const jiStructInfo: std.builtin.Type.Struct = @typeInfo(EnabledSdlJoystickImplementations).Struct;
    //Iterate over all fields on the video implementations struct
    inline for (jiStructInfo.fields) |field| {
        var enabled: bool = @field(sdl_options.joystick_implementations, field.name);
        //If its enabled in the options
        if (enabled) {
            //they arent consistent with their naming always :/
            if (std.mem.eql(u8, field.name, "darwin")) {
                lib.defineCMacro("SDL_JOYSTICK_IOKIT", "1");
            } else if (std.mem.eql(u8, field.name, "bsd")) {
                lib.defineCMacro("SDL_JOYSTICK_USBHID", "1");
            } else {
                //Make the macro name
                var name = try std.mem.concat(b.allocator, u8, &.{
                    "SDL_JOYSTICK_",
                    try lazyToUpper(b.allocator, field.name),
                });
                //Set the macro to 1
                lib.defineCMacro(name, "1");
                // std.debug.print("enabling joystick driver {s} from {s} upper {s}\n", .{ name, field.name, try lazyToUpper(b.allocator, field.name) });
            }
        }
    }

    switch (target.getOsTag()) {
        //TODO: figure out why when linking against our built SDL it causes a linker failure `__stack_chk_fail was replaced` on windows
        .windows => {
            lib.addCSourceFiles(&windows_src_files, c_flags.items);

            lib.linkSystemLibrary("setupapi");
            lib.linkSystemLibrary("winmm");
            lib.linkSystemLibrary("gdi32");
            lib.linkSystemLibrary("imm32");
            lib.linkSystemLibrary("version");
            lib.linkSystemLibrary("oleaut32");
            lib.linkSystemLibrary("ole32");
        },
        .macos => {
            lib.addCSourceFiles(&darwin_src_files, c_flags.items);

            var obj_flags = try std.mem.concat(b.allocator, []const u8, &.{ &.{"-fobjc-arc"}, c_flags.items });
            lib.addCSourceFiles(&objective_c_src_files, obj_flags);
        },
        .linux => {
            lib.addCSourceFiles(&linux_src_files, c_flags.items);
        },
        else => {
            // const config_header = b.addConfigHeader(.{
            //     .style = .{ .cmake = .{ .path = root_path ++ "include/SDL_config.h.cmake" } },
            //     .include_path = root_path ++ "SDL2/SDL_config.h",
            // }, .{});

            // lib.addConfigHeader(config_header);
            // lib.installConfigHeader(config_header, .{});
        },
    }

    try applyLinkerArgs(b.allocator, target, lib);

    switch (sdl_options.thread_implementation) {
        //stdcpp and ngage have cpp code, so lets add exceptions for those, since find_c_cpp_sources separates the found c/cpp files
        .stdcpp => lib.addCSourceFiles((try find_c_cpp_sources(b.allocator, root_path ++ "src/thread/stdcpp/")).cpp, c_flags.items),
        .ngage => lib.addCSourceFiles((try find_c_cpp_sources(b.allocator, root_path ++ "src/thread/ngage/")).cpp, c_flags.items),
        //Windows implementation of thread requires parts of the generic implementation,
        //not sure if this is fully correct (or if we need to define SDL_THREAD_GENERIC_COND_SUFFIX)
        //due to a linker error on Windows that happens earlier on, but it seems fine enough for now, and can be tested later
        .windows => {
            lib.addCSourceFile(root_path ++ "src/thread/generic/SDL_syscond.c", c_flags.items);
            lib.addCSourceFiles((try find_c_cpp_sources(b.allocator, root_path ++ "src/thread/windows/")).c, c_flags.items);
        },
        else => |value| {
            const path = try std.mem.concat(b.allocator, u8, &.{ root_path, "src/thread/", @tagName(value), "/" });
            lib.addCSourceFiles((try find_c_cpp_sources(b.allocator, path)).c, c_flags.items);
        },
    }

    if (sdl_options.power_implementation) |chosen| {
        switch (chosen) {
            //TODO: uikit uses a .m file, we should handle that!
            .winrt => lib.addCSourceFile(root_path ++ "src/power/winrt/SDL_syspower.cpp", c_flags.items),
            else => |value| {
                const path = try std.mem.concat(b.allocator, u8, &.{ root_path, "src/power/", @tagName(value), "/SDL_syspower.c" });
                lib.addCSourceFile(path, c_flags.items);
            },
        }
    } else {
        //if theres no power implementation, disable SDL_Power alltogether
        lib.defineCMacro("SDL_POWER_DISABLED", "1");
    }

    switch (sdl_options.timer_implementation) {
        .ngage => lib.addCSourceFile(root_path ++ "src/timer/ngage/SDL_systimer.cpp", c_flags.items),
        else => |value| {
            const path = try std.mem.concat(b.allocator, u8, &.{ root_path, "src/timer/", @tagName(value), "/SDL_systimer.c" });
            lib.addCSourceFile(path, c_flags.items);
        },
    }

    switch (sdl_options.locale_implementation) {
        //haiku is a .cc file (cpp?)
        .haiku => lib.addCSourceFile(root_path ++ "src/locale/haiku/SDL_syslocale.cc", c_flags.items),
        //macos is a .m file (obj-c)
        .macosx => lib.addCSourceFile(root_path ++ "src/locale/macosx/SDL_syslocale.m", try std.mem.concat(b.allocator, []const u8, &.{ c_flags.items, &.{"-fobjc-arc"} })),
        else => |value| {
            const path = try std.mem.concat(b.allocator, u8, &.{ root_path, "src/locale/", @tagName(value), "/SDL_syslocale.c" });
            lib.addCSourceFile(path, c_flags.items);
        },
    }

    { //video implementations
        if (sdl_options.video_implementations.x11) {
            lib.linkSystemLibrary("X11");
            lib.linkSystemLibrary("Xext");

            var src_files = try find_c_cpp_sources(b.allocator, root_path ++ "src/video/x11/");

            lib.addCSourceFiles(src_files.c, c_flags.items);
        }

        if (sdl_options.video_implementations.wayland) {
            //TODO: fix linker errors here from the wayland headers,

            lib.linkSystemLibrary("wayland-client");
            lib.linkSystemLibrary("wayland-cursor");
            lib.linkSystemLibrary("wayland-egl");
            lib.linkSystemLibrary("xkbcommon");

            lib.addIncludePath(root_path ++ "include/wayland-protocols");

            var src_files = try find_c_cpp_sources(b.allocator, root_path ++ "src/video/wayland/");
            lib.addCSourceFiles(src_files.c, c_flags.items);
        }

        if (sdl_options.video_implementations.windows) {
            var src_files = try find_c_cpp_sources(b.allocator, root_path ++ "src/video/windows/");

            lib.addCSourceFiles(src_files.c, c_flags.items);
        }

        //TODO: the rest of the video implementations
    } //video implementations

    { //joystick implementations
        if (sdl_options.joystick_implementations.dummy) {
            lib.addCSourceFile(root_path ++ "src/joystick/dummy/SDL_sysjoystick.c", c_flags.items);
        }

        if (sdl_options.joystick_implementations.linux) {
            lib.addCSourceFile(root_path ++ "src/joystick/linux/SDL_sysjoystick.c", c_flags.items);
        }

        //dinput, xinput, and rawinput are all windows exclusives, so if any of them are on, we need the windows joystick
        if (sdl_options.joystick_implementations.dinput or sdl_options.joystick_implementations.xinput or sdl_options.joystick_implementations.rawinput) {
            lib.addCSourceFile(root_path ++ "src/joystick/windows/SDL_windowsjoystick.c", c_flags.items);
        }

        if (sdl_options.joystick_implementations.dinput) {
            lib.addCSourceFile(root_path ++ "src/joystick/windows/SDL_dinputjoystick.c", c_flags.items);
        }

        if (sdl_options.joystick_implementations.xinput) {
            lib.addCSourceFile(root_path ++ "src/joystick/windows/SDL_xinputjoystick.c", c_flags.items);
        }

        if (sdl_options.joystick_implementations.rawinput) {
            lib.addCSourceFile(root_path ++ "src/joystick/windows/SDL_rawinputjoystick.c", c_flags.items);
        }

        if (sdl_options.joystick_implementations.wgi) {
            lib.addCSourceFile(root_path ++ "src/joystick/windows/windows_gaming_input.c", c_flags.items);
        }

        if (sdl_options.joystick_implementations.steam) {
            lib.addCSourceFile(root_path ++ "src/joystick/steam/SDL_steamcontroller.c", c_flags.items);
        }
    } //joystick implementations

    { //haptic implementations
        if (sdl_options.haptic_implementation == .android) {
            lib.addCSourceFile(root_path ++ "src/haptic/android/SDL_syshaptic.c", c_flags.items);
        }

        if (sdl_options.haptic_implementation == .darwin) {
            lib.addCSourceFile(root_path ++ "src/haptic/darwin/SDL_syshaptic.c", c_flags.items);
        }

        if (sdl_options.haptic_implementation == .dummy) {
            lib.addCSourceFile(root_path ++ "src/haptic/dummy/SDL_syshaptic.c", c_flags.items);
        }

        if (sdl_options.haptic_implementation == .linux) {
            lib.addCSourceFile(root_path ++ "src/haptic/linux/SDL_syshaptic.c", c_flags.items);
        }

        if (sdl_options.haptic_implementation == .windows) {
            lib.addCSourceFile(root_path ++ "src/haptic/windows/SDL_dinputhaptic.c", c_flags.items);
            lib.addCSourceFile(root_path ++ "src/haptic/windows/SDL_windowshaptic.c", c_flags.items);
            lib.addCSourceFile(root_path ++ "src/haptic/windows/SDL_xinputhaptic.c", c_flags.items);
        }
    } //haptic implementations

    lib.installHeadersDirectory(root_path ++ "include", "SDL2");

    return lib;
}

pub fn applyLinkerArgs(allocator: std.mem.Allocator, target: std.zig.CrossTarget, lib: *std.Build.CompileStep) !void {
    switch (target.getOsTag()) {
        .linux => {
            lib.addIncludePath(root_path ++ "../system-sdk/linux/include");
            lib.addLibraryPath(try std.mem.concat(allocator, u8, &.{ root_path ++ "../system-sdk/linux/lib/", try target.linuxTriple(allocator) }));
        },
        .macos => {
            lib.addFrameworkPath(root_path ++ "../system-sdk/macos12/System/Library/Frameworks");
            lib.addSystemIncludePath(root_path ++ "../system-sdk/macos12/usr/include");
            lib.addLibraryPath(root_path ++ "../system-sdk/macos12/usr/lib");

            lib.linkSystemLibraryName("objc");

            lib.linkFramework("AppKit");
            lib.linkFramework("OpenGL");
            lib.linkFramework("CoreFoundation");
            lib.linkFramework("CoreServices");
            lib.linkFramework("CoreGraphics");
            lib.linkFramework("Metal");
            lib.linkFramework("CoreVideo");
            lib.linkFramework("Cocoa");
            lib.linkFramework("IOKit");
            lib.linkFramework("ForceFeedback");
            lib.linkFramework("Carbon");
            lib.linkFramework("CoreAudio");
            lib.linkFramework("AudioToolbox");
            lib.linkFramework("Foundation");
        },
        else => {},
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var options = getDefaultOptionsForTarget(target);

    options.shared = b.option(bool, "shared", "Whether to build a shared or static library") orelse false;

    b.installArtifact(try createSDL(b, target, optimize, options));
}

///Finds all c/cpp sources in a folder recursively
///Each type of file is split into its own array so that caller can specify specific compilation flags for each filetype
///Caller owns returned memory (but that doesnt really matter in the build script, we just dont clear anything :^)
fn find_c_cpp_sources(allocator: std.mem.Allocator, search_path: []const u8) !struct { c: []const []const u8, cpp: []const []const u8 } {
    var c_list = std.ArrayList([]const u8).init(allocator);
    var cpp_list = std.ArrayList([]const u8).init(allocator);

    var dir = try std.fs.openIterableDirAbsolute(search_path, .{});
    defer dir.close();

    var walker: std.fs.IterableDir.Walker = try dir.walk(allocator);
    defer walker.deinit();

    var itr_next: ?std.fs.IterableDir.Walker.WalkerEntry = try walker.next();
    while (itr_next != null) {
        var next: std.fs.IterableDir.Walker.WalkerEntry = itr_next.?;

        //if the file is a c source file
        if (std.mem.endsWith(u8, next.path, ".c")) {
            var item = try allocator.alloc(u8, next.path.len + search_path.len);

            //copy the root first
            std.mem.copy(u8, item, search_path);

            //copy the filepath next
            std.mem.copy(u8, item[search_path.len..], next.path);

            try c_list.append(item);
        }

        //if the file is a cpp source file
        if (std.mem.endsWith(u8, next.path, ".cpp")) {
            var item = try allocator.alloc(u8, next.path.len + search_path.len);

            //copy the root first
            std.mem.copy(u8, item, search_path);

            //copy the filepath next
            std.mem.copy(u8, item[search_path.len..], next.path);

            try cpp_list.append(item);
        }

        itr_next = try walker.next();
    }

    return .{ .c = try c_list.toOwnedSlice(), .cpp = try cpp_list.toOwnedSlice() };
}

fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const root_path = root() ++ "/";

const generic_src_files = [_][]const u8{
    root_path ++ "src/SDL.c",
    root_path ++ "src/SDL_assert.c",
    root_path ++ "src/SDL_dataqueue.c",
    root_path ++ "src/SDL_error.c",
    root_path ++ "src/SDL_guid.c",
    root_path ++ "src/SDL_hints.c",
    root_path ++ "src/SDL_list.c",
    root_path ++ "src/SDL_log.c",
    root_path ++ "src/SDL_utils.c",
    root_path ++ "src/atomic/SDL_atomic.c",
    root_path ++ "src/atomic/SDL_spinlock.c",
    root_path ++ "src/audio/SDL_audio.c",
    root_path ++ "src/audio/SDL_audiocvt.c",
    root_path ++ "src/audio/SDL_audiodev.c",
    root_path ++ "src/audio/SDL_audiotypecvt.c",
    root_path ++ "src/audio/SDL_mixer.c",
    root_path ++ "src/audio/SDL_wave.c",
    root_path ++ "src/cpuinfo/SDL_cpuinfo.c",
    root_path ++ "src/dynapi/SDL_dynapi.c",
    root_path ++ "src/events/SDL_clipboardevents.c",
    root_path ++ "src/events/SDL_displayevents.c",
    root_path ++ "src/events/SDL_dropevents.c",
    root_path ++ "src/events/SDL_events.c",
    root_path ++ "src/events/SDL_gesture.c",
    root_path ++ "src/events/SDL_keyboard.c",
    root_path ++ "src/events/SDL_keysym_to_scancode.c",
    root_path ++ "src/events/SDL_mouse.c",
    root_path ++ "src/events/SDL_quit.c",
    root_path ++ "src/events/SDL_scancode_tables.c",
    root_path ++ "src/events/SDL_touch.c",
    root_path ++ "src/events/SDL_windowevents.c",
    root_path ++ "src/events/imKStoUCS.c",
    root_path ++ "src/file/SDL_rwops.c",
    root_path ++ "src/haptic/SDL_haptic.c",
    root_path ++ "src/hidapi/SDL_hidapi.c",

    root_path ++ "src/joystick/SDL_gamecontroller.c",
    root_path ++ "src/joystick/SDL_joystick.c",
    root_path ++ "src/joystick/controller_type.c",
    root_path ++ "src/joystick/virtual/SDL_virtualjoystick.c",

    root_path ++ "src/libm/e_atan2.c",
    root_path ++ "src/libm/e_exp.c",
    root_path ++ "src/libm/e_fmod.c",
    root_path ++ "src/libm/e_log.c",
    root_path ++ "src/libm/e_log10.c",
    root_path ++ "src/libm/e_pow.c",
    root_path ++ "src/libm/e_rem_pio2.c",
    root_path ++ "src/libm/e_sqrt.c",
    root_path ++ "src/libm/k_cos.c",
    root_path ++ "src/libm/k_rem_pio2.c",
    root_path ++ "src/libm/k_sin.c",
    root_path ++ "src/libm/k_tan.c",
    root_path ++ "src/libm/s_atan.c",
    root_path ++ "src/libm/s_copysign.c",
    root_path ++ "src/libm/s_cos.c",
    root_path ++ "src/libm/s_fabs.c",
    root_path ++ "src/libm/s_floor.c",
    root_path ++ "src/libm/s_scalbn.c",
    root_path ++ "src/libm/s_sin.c",
    root_path ++ "src/libm/s_tan.c",
    root_path ++ "src/locale/SDL_locale.c",
    root_path ++ "src/misc/SDL_url.c",
    root_path ++ "src/power/SDL_power.c",
    root_path ++ "src/render/SDL_d3dmath.c",
    root_path ++ "src/render/SDL_render.c",
    root_path ++ "src/render/SDL_yuv_sw.c",
    root_path ++ "src/sensor/SDL_sensor.c",
    root_path ++ "src/stdlib/SDL_crc16.c",
    root_path ++ "src/stdlib/SDL_crc32.c",
    root_path ++ "src/stdlib/SDL_getenv.c",
    root_path ++ "src/stdlib/SDL_iconv.c",
    root_path ++ "src/stdlib/SDL_malloc.c",
    root_path ++ "src/stdlib/SDL_mslibc.c",
    root_path ++ "src/stdlib/SDL_qsort.c",
    root_path ++ "src/stdlib/SDL_stdlib.c",
    root_path ++ "src/stdlib/SDL_string.c",
    root_path ++ "src/stdlib/SDL_strtokr.c",
    root_path ++ "src/thread/SDL_thread.c",
    root_path ++ "src/timer/SDL_timer.c",
    root_path ++ "src/video/SDL_RLEaccel.c",
    root_path ++ "src/video/SDL_blit.c",
    root_path ++ "src/video/SDL_blit_0.c",
    root_path ++ "src/video/SDL_blit_1.c",
    root_path ++ "src/video/SDL_blit_A.c",
    root_path ++ "src/video/SDL_blit_N.c",
    root_path ++ "src/video/SDL_blit_auto.c",
    root_path ++ "src/video/SDL_blit_copy.c",
    root_path ++ "src/video/SDL_blit_slow.c",
    root_path ++ "src/video/SDL_bmp.c",
    root_path ++ "src/video/SDL_clipboard.c",
    root_path ++ "src/video/SDL_egl.c",
    root_path ++ "src/video/SDL_fillrect.c",
    root_path ++ "src/video/SDL_pixels.c",
    root_path ++ "src/video/SDL_rect.c",
    root_path ++ "src/video/SDL_shape.c",
    root_path ++ "src/video/SDL_stretch.c",
    root_path ++ "src/video/SDL_surface.c",
    root_path ++ "src/video/SDL_video.c",
    root_path ++ "src/video/SDL_vulkan_utils.c",
    root_path ++ "src/video/SDL_yuv.c",
    root_path ++ "src/video/yuv2rgb/yuv_rgb.c",

    root_path ++ "src/video/dummy/SDL_nullevents.c",
    root_path ++ "src/video/dummy/SDL_nullframebuffer.c",
    root_path ++ "src/video/dummy/SDL_nullvideo.c",

    root_path ++ "src/render/software/SDL_blendfillrect.c",
    root_path ++ "src/render/software/SDL_blendline.c",
    root_path ++ "src/render/software/SDL_blendpoint.c",
    root_path ++ "src/render/software/SDL_drawline.c",
    root_path ++ "src/render/software/SDL_drawpoint.c",
    root_path ++ "src/render/software/SDL_render_sw.c",
    root_path ++ "src/render/software/SDL_rotate.c",
    root_path ++ "src/render/software/SDL_triangle.c",

    root_path ++ "src/audio/dummy/SDL_dummyaudio.c",

    root_path ++ "src/joystick/hidapi/SDL_hidapi_combined.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_gamecube.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_luna.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_ps3.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_ps4.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_ps5.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_rumble.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_shield.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_stadia.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_steam.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_switch.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_wii.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_xbox360.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_xbox360w.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapi_xboxone.c",
    root_path ++ "src/joystick/hidapi/SDL_hidapijoystick.c",
};

const windows_src_files = [_][]const u8{
    root_path ++ "src/core/windows/SDL_hid.c",
    root_path ++ "src/core/windows/SDL_immdevice.c",
    root_path ++ "src/core/windows/SDL_windows.c",
    root_path ++ "src/core/windows/SDL_xinput.c",
    root_path ++ "src/filesystem/windows/SDL_sysfilesystem.c",
    // root_path ++ "src/hidapi/windows/hid.c",
    // This can be enabled when Zig updates to the next mingw-w64 release,
    // which will make the headers gain `windows.gaming.input.h`.
    // Also revert the patch 2c79fd8fd04f1e5045cbe5978943b0aea7593110.
    //"src/joystick/windows/SDL_windows_gaming_input.c",

    root_path ++ "src/loadso/windows/SDL_sysloadso.c",
    // root_path ++ "src/main/windows/SDL_windows_main.c",
    root_path ++ "src/misc/windows/SDL_sysurl.c",
    root_path ++ "src/sensor/windows/SDL_windowssensor.c",

    root_path ++ "src/render/direct3d/SDL_render_d3d.c",
    root_path ++ "src/render/direct3d/SDL_shaders_d3d.c",
    root_path ++ "src/render/direct3d11/SDL_render_d3d11.c",
    root_path ++ "src/render/direct3d11/SDL_shaders_d3d11.c",
    root_path ++ "src/render/direct3d12/SDL_render_d3d12.c",
    root_path ++ "src/render/direct3d12/SDL_shaders_d3d12.c",

    root_path ++ "src/audio/directsound/SDL_directsound.c",
    root_path ++ "src/audio/wasapi/SDL_wasapi.c",
    root_path ++ "src/audio/wasapi/SDL_wasapi_win32.c",
    root_path ++ "src/audio/winmm/SDL_winmm.c",
    root_path ++ "src/audio/disk/SDL_diskaudio.c",

    root_path ++ "src/render/opengl/SDL_render_gl.c",
    root_path ++ "src/render/opengl/SDL_shaders_gl.c",
    root_path ++ "src/render/opengles/SDL_render_gles.c",
    root_path ++ "src/render/opengles2/SDL_render_gles2.c",
    root_path ++ "src/render/opengles2/SDL_shaders_gles2.c",
};

const linux_src_files = [_][]const u8{
    root_path ++ "src/core/linux/SDL_dbus.c",
    root_path ++ "src/core/linux/SDL_evdev.c",
    root_path ++ "src/core/linux/SDL_evdev_capabilities.c",
    root_path ++ "src/core/linux/SDL_evdev_kbd.c",
    root_path ++ "src/core/linux/SDL_ibus.c",
    root_path ++ "src/core/linux/SDL_ime.c",
    root_path ++ "src/core/linux/SDL_sandbox.c",
    root_path ++ "src/core/linux/SDL_threadprio.c",
    root_path ++ "src/core/linux/SDL_udev.c",
    // "src/core/linux/SDL_fcitx.c",
    root_path ++ "src/core/unix/SDL_poll.c",

    root_path ++ "src/hidapi/linux/hid.c",

    root_path ++ "src/sensor/dummy/SDL_dummysensor.c",

    root_path ++ "src/misc/unix/SDL_sysurl.c",

    root_path ++ "src/audio/alsa/SDL_alsa_audio.c",
    root_path ++ "src/audio/jack/SDL_jackaudio.c",
    root_path ++ "src/audio/pulseaudio/SDL_pulseaudio.c",
};

const darwin_src_files = [_][]const u8{
    root_path ++ "src/joystick/darwin/SDL_iokitjoystick.c",
    // root_path ++ "src/power/macosx/SDL_syspower.c",
    root_path ++ "src/loadso/dlopen/SDL_sysloadso.c",
    root_path ++ "src/audio/disk/SDL_diskaudio.c",
    root_path ++ "src/render/opengl/SDL_render_gl.c",
    root_path ++ "src/render/opengl/SDL_shaders_gl.c",
    root_path ++ "src/render/opengles/SDL_render_gles.c",
    root_path ++ "src/render/opengles2/SDL_render_gles2.c",
    root_path ++ "src/render/opengles2/SDL_shaders_gles2.c",
    root_path ++ "src/sensor/dummy/SDL_dummysensor.c",
};

const objective_c_src_files = [_][]const u8{
    root_path ++ "src/audio/coreaudio/SDL_coreaudio.m",
    root_path ++ "src/file/cocoa/SDL_rwopsbundlesupport.m",
    root_path ++ "src/filesystem/cocoa/SDL_sysfilesystem.m",
    //"src/hidapi/testgui/mac_support_cocoa.m",
    // This appears to be for SDL3 only.
    //"src/joystick/apple/SDL_mfijoystick.m",
    root_path ++ "src/misc/macosx/SDL_sysurl.m",
    // root_path ++ "src/power/uikit/SDL_syspower.m",
    root_path ++ "src/render/metal/SDL_render_metal.m",
    root_path ++ "src/sensor/coremotion/SDL_coremotionsensor.m",
    root_path ++ "src/video/cocoa/SDL_cocoaclipboard.m",
    root_path ++ "src/video/cocoa/SDL_cocoaevents.m",
    root_path ++ "src/video/cocoa/SDL_cocoakeyboard.m",
    root_path ++ "src/video/cocoa/SDL_cocoamessagebox.m",
    root_path ++ "src/video/cocoa/SDL_cocoametalview.m",
    root_path ++ "src/video/cocoa/SDL_cocoamodes.m",
    root_path ++ "src/video/cocoa/SDL_cocoamouse.m",
    root_path ++ "src/video/cocoa/SDL_cocoaopengl.m",
    root_path ++ "src/video/cocoa/SDL_cocoaopengles.m",
    root_path ++ "src/video/cocoa/SDL_cocoashape.m",
    root_path ++ "src/video/cocoa/SDL_cocoavideo.m",
    root_path ++ "src/video/cocoa/SDL_cocoavulkan.m",
    root_path ++ "src/video/cocoa/SDL_cocoawindow.m",
    root_path ++ "src/video/uikit/SDL_uikitappdelegate.m",
    root_path ++ "src/video/uikit/SDL_uikitclipboard.m",
    root_path ++ "src/video/uikit/SDL_uikitevents.m",
    root_path ++ "src/video/uikit/SDL_uikitmessagebox.m",
    root_path ++ "src/video/uikit/SDL_uikitmetalview.m",
    root_path ++ "src/video/uikit/SDL_uikitmodes.m",
    root_path ++ "src/video/uikit/SDL_uikitopengles.m",
    root_path ++ "src/video/uikit/SDL_uikitopenglview.m",
    root_path ++ "src/video/uikit/SDL_uikitvideo.m",
    root_path ++ "src/video/uikit/SDL_uikitview.m",
    root_path ++ "src/video/uikit/SDL_uikitviewcontroller.m",
    root_path ++ "src/video/uikit/SDL_uikitvulkan.m",
    root_path ++ "src/video/uikit/SDL_uikitwindow.m",
};

const ios_src_files = [_][]const u8{
    root_path ++ "src/hidapi/ios/hid.m",
    root_path ++ "src/misc/ios/SDL_sysurl.m",
    root_path ++ "src/joystick/iphoneos/SDL_mfijoystick.m",
};

const unknown_src_files = [_][]const u8{
    root_path ++ "src/audio/aaudio/SDL_aaudio.c",
    root_path ++ "src/audio/android/SDL_androidaudio.c",
    root_path ++ "src/audio/arts/SDL_artsaudio.c",
    root_path ++ "src/audio/dsp/SDL_dspaudio.c",
    root_path ++ "src/audio/emscripten/SDL_emscriptenaudio.c",
    root_path ++ "src/audio/esd/SDL_esdaudio.c",
    root_path ++ "src/audio/fusionsound/SDL_fsaudio.c",
    root_path ++ "src/audio/n3ds/SDL_n3dsaudio.c",
    root_path ++ "src/audio/nacl/SDL_naclaudio.c",
    root_path ++ "src/audio/nas/SDL_nasaudio.c",
    root_path ++ "src/audio/netbsd/SDL_netbsdaudio.c",
    root_path ++ "src/audio/openslES/SDL_openslES.c",
    root_path ++ "src/audio/os2/SDL_os2audio.c",
    root_path ++ "src/audio/paudio/SDL_paudio.c",
    root_path ++ "src/audio/pipewire/SDL_pipewire.c",
    root_path ++ "src/audio/ps2/SDL_ps2audio.c",
    root_path ++ "src/audio/psp/SDL_pspaudio.c",
    root_path ++ "src/audio/qsa/SDL_qsa_audio.c",
    root_path ++ "src/audio/sndio/SDL_sndioaudio.c",
    root_path ++ "src/audio/sun/SDL_sunaudio.c",
    root_path ++ "src/audio/vita/SDL_vitaaudio.c",

    root_path ++ "src/core/android/SDL_android.c",
    root_path ++ "src/core/freebsd/SDL_evdev_kbd_freebsd.c",
    root_path ++ "src/core/openbsd/SDL_wscons_kbd.c",
    root_path ++ "src/core/openbsd/SDL_wscons_mouse.c",
    root_path ++ "src/core/os2/SDL_os2.c",
    root_path ++ "src/core/os2/geniconv/geniconv.c",
    root_path ++ "src/core/os2/geniconv/os2cp.c",
    root_path ++ "src/core/os2/geniconv/os2iconv.c",
    root_path ++ "src/core/os2/geniconv/sys2utf8.c",
    root_path ++ "src/core/os2/geniconv/test.c",

    root_path ++ "src/file/n3ds/SDL_rwopsromfs.c",

    root_path ++ "src/filesystem/android/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/dummy/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/emscripten/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/n3ds/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/nacl/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/os2/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/ps2/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/psp/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/riscos/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/unix/SDL_sysfilesystem.c",
    root_path ++ "src/filesystem/vita/SDL_sysfilesystem.c",

    root_path ++ "src/hidapi/libusb/hid.c",
    root_path ++ "src/hidapi/mac/hid.c",

    root_path ++ "src/joystick/android/SDL_sysjoystick.c",
    root_path ++ "src/joystick/bsd/SDL_bsdjoystick.c",
    root_path ++ "src/joystick/dummy/SDL_sysjoystick.c",
    root_path ++ "src/joystick/emscripten/SDL_sysjoystick.c",
    root_path ++ "src/joystick/n3ds/SDL_sysjoystick.c",
    root_path ++ "src/joystick/os2/SDL_os2joystick.c",
    root_path ++ "src/joystick/ps2/SDL_sysjoystick.c",
    root_path ++ "src/joystick/psp/SDL_sysjoystick.c",
    root_path ++ "src/joystick/steam/SDL_steamcontroller.c",
    root_path ++ "src/joystick/vita/SDL_sysjoystick.c",

    root_path ++ "src/loadso/dummy/SDL_sysloadso.c",
    root_path ++ "src/loadso/os2/SDL_sysloadso.c",

    root_path ++ "src/main/android/SDL_android_main.c",
    root_path ++ "src/main/dummy/SDL_dummy_main.c",
    root_path ++ "src/main/gdk/SDL_gdk_main.c",
    root_path ++ "src/main/n3ds/SDL_n3ds_main.c",
    root_path ++ "src/main/nacl/SDL_nacl_main.c",
    root_path ++ "src/main/ps2/SDL_ps2_main.c",
    root_path ++ "src/main/psp/SDL_psp_main.c",
    root_path ++ "src/main/uikit/SDL_uikit_main.c",

    root_path ++ "src/misc/android/SDL_sysurl.c",
    root_path ++ "src/misc/dummy/SDL_sysurl.c",
    root_path ++ "src/misc/emscripten/SDL_sysurl.c",
    root_path ++ "src/misc/riscos/SDL_sysurl.c",
    root_path ++ "src/misc/unix/SDL_sysurl.c",
    root_path ++ "src/misc/vita/SDL_sysurl.c",

    // root_path ++ "src/power/android/SDL_syspower.c",
    // root_path ++ "src/power/emscripten/SDL_syspower.c",
    // root_path ++ "src/power/haiku/SDL_syspower.c",
    // root_path ++ "src/power/n3ds/SDL_syspower.c",
    // root_path ++ "src/power/psp/SDL_syspower.c",
    // root_path ++ "src/power/vita/SDL_syspower.c",

    root_path ++ "src/sensor/android/SDL_androidsensor.c",
    root_path ++ "src/sensor/n3ds/SDL_n3dssensor.c",
    root_path ++ "src/sensor/vita/SDL_vitasensor.c",

    root_path ++ "src/test/SDL_test_assert.c",
    root_path ++ "src/test/SDL_test_common.c",
    root_path ++ "src/test/SDL_test_compare.c",
    root_path ++ "src/test/SDL_test_crc32.c",
    root_path ++ "src/test/SDL_test_font.c",
    root_path ++ "src/test/SDL_test_fuzzer.c",
    root_path ++ "src/test/SDL_test_harness.c",
    root_path ++ "src/test/SDL_test_imageBlit.c",
    root_path ++ "src/test/SDL_test_imageBlitBlend.c",
    root_path ++ "src/test/SDL_test_imageFace.c",
    root_path ++ "src/test/SDL_test_imagePrimitives.c",
    root_path ++ "src/test/SDL_test_imagePrimitivesBlend.c",
    root_path ++ "src/test/SDL_test_log.c",
    root_path ++ "src/test/SDL_test_md5.c",
    root_path ++ "src/test/SDL_test_memory.c",
    root_path ++ "src/test/SDL_test_random.c",

    root_path ++ "src/video/android/SDL_androidclipboard.c",
    root_path ++ "src/video/android/SDL_androidevents.c",
    root_path ++ "src/video/android/SDL_androidgl.c",
    root_path ++ "src/video/android/SDL_androidkeyboard.c",
    root_path ++ "src/video/android/SDL_androidmessagebox.c",
    root_path ++ "src/video/android/SDL_androidmouse.c",
    root_path ++ "src/video/android/SDL_androidtouch.c",
    root_path ++ "src/video/android/SDL_androidvideo.c",
    root_path ++ "src/video/android/SDL_androidvulkan.c",
    root_path ++ "src/video/android/SDL_androidwindow.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_WM.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_dyn.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_events.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_modes.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_mouse.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_opengl.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_render.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_shape.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_video.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_vulkan.c",
    root_path ++ "src/video/directfb/SDL_DirectFB_window.c",
    root_path ++ "src/video/emscripten/SDL_emscriptenevents.c",
    root_path ++ "src/video/emscripten/SDL_emscriptenframebuffer.c",
    root_path ++ "src/video/emscripten/SDL_emscriptenmouse.c",
    root_path ++ "src/video/emscripten/SDL_emscriptenopengles.c",
    root_path ++ "src/video/emscripten/SDL_emscriptenvideo.c",
    root_path ++ "src/video/kmsdrm/SDL_kmsdrmdyn.c",
    root_path ++ "src/video/kmsdrm/SDL_kmsdrmevents.c",
    root_path ++ "src/video/kmsdrm/SDL_kmsdrmmouse.c",
    root_path ++ "src/video/kmsdrm/SDL_kmsdrmopengles.c",
    root_path ++ "src/video/kmsdrm/SDL_kmsdrmvideo.c",
    root_path ++ "src/video/kmsdrm/SDL_kmsdrmvulkan.c",
    root_path ++ "src/video/n3ds/SDL_n3dsevents.c",
    root_path ++ "src/video/n3ds/SDL_n3dsframebuffer.c",
    root_path ++ "src/video/n3ds/SDL_n3dsswkb.c",
    root_path ++ "src/video/n3ds/SDL_n3dstouch.c",
    root_path ++ "src/video/n3ds/SDL_n3dsvideo.c",
    root_path ++ "src/video/nacl/SDL_naclevents.c",
    root_path ++ "src/video/nacl/SDL_naclglue.c",
    root_path ++ "src/video/nacl/SDL_naclopengles.c",
    root_path ++ "src/video/nacl/SDL_naclvideo.c",
    root_path ++ "src/video/nacl/SDL_naclwindow.c",
    root_path ++ "src/video/offscreen/SDL_offscreenevents.c",
    root_path ++ "src/video/offscreen/SDL_offscreenframebuffer.c",
    root_path ++ "src/video/offscreen/SDL_offscreenopengles.c",
    root_path ++ "src/video/offscreen/SDL_offscreenvideo.c",
    root_path ++ "src/video/offscreen/SDL_offscreenwindow.c",
    root_path ++ "src/video/os2/SDL_os2dive.c",
    root_path ++ "src/video/os2/SDL_os2messagebox.c",
    root_path ++ "src/video/os2/SDL_os2mouse.c",
    root_path ++ "src/video/os2/SDL_os2util.c",
    root_path ++ "src/video/os2/SDL_os2video.c",
    root_path ++ "src/video/os2/SDL_os2vman.c",
    root_path ++ "src/video/pandora/SDL_pandora.c",
    root_path ++ "src/video/pandora/SDL_pandora_events.c",
    root_path ++ "src/video/ps2/SDL_ps2video.c",
    root_path ++ "src/video/psp/SDL_pspevents.c",
    root_path ++ "src/video/psp/SDL_pspgl.c",
    root_path ++ "src/video/psp/SDL_pspmouse.c",
    root_path ++ "src/video/psp/SDL_pspvideo.c",
    root_path ++ "src/video/qnx/gl.c",
    root_path ++ "src/video/qnx/keyboard.c",
    root_path ++ "src/video/qnx/video.c",
    root_path ++ "src/video/raspberry/SDL_rpievents.c",
    root_path ++ "src/video/raspberry/SDL_rpimouse.c",
    root_path ++ "src/video/raspberry/SDL_rpiopengles.c",
    root_path ++ "src/video/raspberry/SDL_rpivideo.c",
    root_path ++ "src/video/riscos/SDL_riscosevents.c",
    root_path ++ "src/video/riscos/SDL_riscosframebuffer.c",
    root_path ++ "src/video/riscos/SDL_riscosmessagebox.c",
    root_path ++ "src/video/riscos/SDL_riscosmodes.c",
    root_path ++ "src/video/riscos/SDL_riscosmouse.c",
    root_path ++ "src/video/riscos/SDL_riscosvideo.c",
    root_path ++ "src/video/riscos/SDL_riscoswindow.c",
    root_path ++ "src/video/vita/SDL_vitaframebuffer.c",
    root_path ++ "src/video/vita/SDL_vitagl_pvr.c",
    root_path ++ "src/video/vita/SDL_vitagles.c",
    root_path ++ "src/video/vita/SDL_vitagles_pvr.c",
    root_path ++ "src/video/vita/SDL_vitakeyboard.c",
    root_path ++ "src/video/vita/SDL_vitamessagebox.c",
    root_path ++ "src/video/vita/SDL_vitamouse.c",
    root_path ++ "src/video/vita/SDL_vitatouch.c",
    root_path ++ "src/video/vita/SDL_vitavideo.c",
    root_path ++ "src/video/vivante/SDL_vivanteopengles.c",
    root_path ++ "src/video/vivante/SDL_vivanteplatform.c",
    root_path ++ "src/video/vivante/SDL_vivantevideo.c",
    root_path ++ "src/video/vivante/SDL_vivantevulkan.c",

    root_path ++ "src/render/opengl/SDL_render_gl.c",
    root_path ++ "src/render/opengl/SDL_shaders_gl.c",
    root_path ++ "src/render/opengles/SDL_render_gles.c",
    root_path ++ "src/render/opengles2/SDL_render_gles2.c",
    root_path ++ "src/render/opengles2/SDL_shaders_gles2.c",
    root_path ++ "src/render/ps2/SDL_render_ps2.c",
    root_path ++ "src/render/psp/SDL_render_psp.c",
    root_path ++ "src/render/vitagxm/SDL_render_vita_gxm.c",
    root_path ++ "src/render/vitagxm/SDL_render_vita_gxm_memory.c",
    root_path ++ "src/render/vitagxm/SDL_render_vita_gxm_tools.c",
};
