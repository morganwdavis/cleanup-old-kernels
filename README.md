# Clean Up Old Linux Kernels

## A Script for Reclaiming Disk Space

As a long-time FreeBSD user and server administrator, I've been eagerly awaiting FreeBSD laptop support that rivals Windows in usability and polish. Meanwhile, I've been experimenting with Linux Mint, hoping that someday FreeBSD can offer a Mint-like desktop experience on top of FreeBSD's excellent operating system foundation.

## Dude, Where's My Disk Space?

One thing I noticed after a while, especially on my old Chromebook repurposed to run Mint, is how Mint accumulates old kernel packages, headers, tools, and modules with every update. Over time, these leftover files pile up significantly. After receiving warning notifications about low disk space, I discovered these old kernel files were consuming over 3GB--a substantial amount on my modest 16GB root filesystem. That was already surprising, but an even bigger surprise was still to come...

## No Clean Up Tool for You!

I initially assumed Mint would provide an automatic cleanup tool or process to remove these obsolete kernels and related files safely. Unfortunately, that's not the case. While `apt autoremove` might help remove some packages, Mint doesn't always mark older kernels for removal automatically. Worse, even after manually uninstalling old kernel packages with `apt`, leftover orphaned directories often remain scattered in `/usr/src`, `/usr/lib/modules`, and other places, continuing to take up precious space.

## Fine! I'll Do It Myself!

Faced with this, I wrote a POSIX-compliant shell script designed to:

- Identify and carefully preserve the current running kernel and the newest installed one
- Purge old kernel packages (images, headers, modules, tools)
- Remove orphaned kernel directories left behind after package removal

This script helps automate the cleanup process and can be run periodically--especially handy on systems with limited disk space.

If you find your Linux Mint system accumulating kernel cruft that eats up storage, this approach can save you plenty of space and headaches. It's always wise to keep at least one previous kernel as a fallback, but keeping dozens of outdated kernels isn't necessary and wastes disk capacity.

Running a cleanup script like this alongside routine system updates can keep your Mint system lean and responsive, especially on laptops or older hardware. As Mint continues to evolve, hopefully better automatic cleanup policies will arrive. Until then, manual or scripted cleaning remains a useful tool in your maintenance arsenal.

> **WARNING! Always make a backup**  before running this (and run it with `--dry-run` to see what it will remove first). I'm still new to the Linux world and not fully aware of any bizarre gotchas that could be lurking.
