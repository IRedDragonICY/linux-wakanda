#!/usr/bin/env python3
import sys
import os

ancestor = sys.argv[1]
current = sys.argv[2] # our version (upstream in rebase, but local in our mental model, wait: in rebase, %A is upstream head, %B is our commit being rebased)
other = sys.argv[3] # their version

# Actually, git merge-file does the heavy lifting
# First, run standard git merge-file which modifies %A
ret = os.system(f"git merge-file -q {current} {ancestor} {other}")

# If simple merge succeeded, we're done
if ret == 0:
    sys.exit(0)

# If it failed, check if the conflict is only around b2sums.
# Usually, upstream updates b2sums for their new rc version, and we have our own b2sums for wakanda-rc.
# We want to keep OUR b2sums.
# In a rebase, current (%A) is upstream, other (%B) is our commit.
# So we want to keep the b2sums from %B (other).
# Let's read %A which now has conflict markers.
with open(current, 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
in_conflict = False
conflict_lines = []

def resolve_conflict(block):
    # A block is an array of lines from <<<<<<< to >>>>>>>.
    # It contains upstream changes (from current) and our changes (from other).
    # We want to see if the conflict is purely about b2sums.
    is_b2sums = False
    for l in block:
        if 'b2sums=' in l:
            is_b2sums = True
            break
            
    if not is_b2sums:
        # Not a b2sums conflict, leave markers intact so user can resolve manually
        return block
        
    # If it is a b2sums conflict, we want "our" version.
    # Wait, in rebase, %A is upstream (above =======), %B is ours (below =======).
    # So we want the lines between ======= and >>>>>>>
    our_lines = []
    found_sep = False
    for l in block:
        if l.startswith('<<<<<<<'): continue
        if l.startswith('======='):
            found_sep = True
            continue
        if l.startswith('>>>>>>>'): continue
        
        if found_sep:
            our_lines.append(l)
            
    return our_lines

for line in lines:
    if line.startswith('<<<<<<<'):
        in_conflict = True
        conflict_lines = [line]
    elif in_conflict:
        conflict_lines.append(line)
        if line.startswith('>>>>>>>'):
            in_conflict = False
            resolved = resolve_conflict(conflict_lines)
            new_lines.extend(resolved)
    else:
        new_lines.append(line)

with open(current, 'w') as f:
    f.writelines(new_lines)

# Re-evaluate if there are any remaining conflicts
if any(line.startswith('<<<<<<<') for line in new_lines):
    sys.exit(1) # Still conflicts
else:
    sys.exit(0) # All conflicts auto-resolved
