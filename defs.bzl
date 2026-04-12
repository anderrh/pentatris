"""Custom Bazel rules for Game Boy ROM development with RGBDS.

Defines three rules:
  gb_includes – declare an include directory (with optional prefix remapping)
  gb_object   – assemble one .asm file into a .o, pulling -I paths from deps
  gb_rom      – link .o files into a .gb ROM and fix the cartridge header
"""

# ---------------------------------------------------------------------------
# Provider: carries include-directory paths between targets
# ---------------------------------------------------------------------------

GbIncInfo = provider(
    doc = "Include directories and files for Game Boy assembly.",
    fields = {
        "includes": "depset of include directory path strings",
        "files": "depset of Files that must be present at assemble time",
    },
)

# ---------------------------------------------------------------------------
# gb_includes
# ---------------------------------------------------------------------------

def _gb_includes_impl(ctx):
    if ctx.attr.prefix:
        # Remap: copy .inc files into <dir>/<prefix>/ so that
        # `INCLUDE "prefix/foo.inc"` resolves with `-I <dir>/`.
        dir = ctx.actions.declare_directory(ctx.label.name)
        cmds = ["mkdir -p {}/{}".format(dir.path, ctx.attr.prefix)]
        for f in ctx.files.srcs:
            cmds.append("cp {} {}/{}/".format(f.path, dir.path, ctx.attr.prefix))
        ctx.actions.run_shell(
            command = " && ".join(cmds),
            inputs = ctx.files.srcs,
            outputs = [dir],
        )
        return [GbIncInfo(
            includes = depset([dir.path]),
            files = depset([dir]),
        )]
    else:
        # Normal: each file's directory becomes an -I path.
        dirs = {f.dirname: True for f in ctx.files.srcs}
        return [GbIncInfo(
            includes = depset(dirs.keys()),
            files = depset(ctx.files.srcs),
        )]

gb_includes = rule(
    implementation = _gb_includes_impl,
    doc = "Declare an include directory for gb_object targets.",
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "prefix": attr.string(
            default = "",
            doc = "If set, files are remapped under this subdirectory " +
                  "(e.g. prefix=\"include\" lets INCLUDE \"include/foo.inc\" work).",
        ),
    },
)

# ---------------------------------------------------------------------------
# gb_object
# ---------------------------------------------------------------------------

def _gb_object_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".o")
    src = ctx.file.src
    rgbasm = ctx.files._rgbasm[0]

    # Merge include info from all deps
    inc_depsets = []
    file_depsets = []
    for dep in ctx.attr.includes:
        info = dep[GbIncInfo]
        inc_depsets.append(info.includes)
        file_depsets.append(info.files)

    all_dirs = depset(transitive = inc_depsets).to_list()
    all_files = depset(transitive = file_depsets)

    inc_flags = " ".join(["-I " + d + "/" for d in all_dirs])

    ctx.actions.run_shell(
        command = "{rgbasm} {flags} -o {out} {src}".format(
            rgbasm = rgbasm.path,
            flags = inc_flags,
            out = out.path,
            src = src.path,
        ),
        inputs = depset([src] + ctx.files.data, transitive = [all_files]),
        outputs = [out],
        tools = [rgbasm],
    )

    return [DefaultInfo(files = depset([out]))]

gb_object = rule(
    implementation = _gb_object_impl,
    doc = "Assemble one .asm source file into a .o object.",
    attrs = {
        "src": attr.label(allow_single_file = [".asm"]),
        "includes": attr.label_list(providers = [GbIncInfo]),
        "data": attr.label_list(
            allow_files = True,
            doc = "Extra files needed at assemble time (e.g. .2bpp for INCBIN).",
        ),
        "_rgbasm": attr.label(
            default = "@rgbds//:rgbasm",
            allow_files = True,
            cfg = "exec",
        ),
    },
)

# ---------------------------------------------------------------------------
# gb_rom
# ---------------------------------------------------------------------------

def _gb_rom_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".gb")
    rgblink = ctx.files._rgblink[0]
    rgbfix = ctx.files._rgbfix[0]

    objs = []
    for dep in ctx.attr.deps:
        objs.extend(dep[DefaultInfo].files.to_list())

    obj_paths = " ".join([o.path for o in objs])

    ctx.actions.run_shell(
        command = "{link} -o {out} {objs} && {fix} -v -p 0xFF -t \"{title}\" -C {out}".format(
            link = rgblink.path,
            fix = rgbfix.path,
            out = out.path,
            objs = obj_paths,
            title = ctx.attr.title,
        ),
        inputs = objs,
        outputs = [out],
        tools = [rgblink, rgbfix],
    )

    return [DefaultInfo(files = depset([out]))]

gb_rom = rule(
    implementation = _gb_rom_impl,
    doc = "Link gb_object targets into a .gb ROM.",
    attrs = {
        "deps": attr.label_list(),
        "title": attr.string(default = "ROM"),
        "_rgblink": attr.label(
            default = "@rgbds//:rgblink",
            allow_files = True,
            cfg = "exec",
        ),
        "_rgbfix": attr.label(
            default = "@rgbds//:rgbfix",
            allow_files = True,
            cfg = "exec",
        ),
    },
)
