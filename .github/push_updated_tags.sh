#!/bin/bash

# Get a list of all local tags
local_tags=$(git tag -l)
if [ -z "$local_tags" ]; then
    echo "No local tags found. Nothing to push."
    exit 0
fi

# Fetch remote tags to ensure we have the latest
echo "Fetching remote tags from '$remote_name'..."
git fetch origin --tags
echo

# Create a temporary directory for comparing tags
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Find tags that differ between local and remote
echo "Checking for tags that differ between local and remote..."
different_tags=()

for tag in $local_tags; do
    # Check if tag exists on remote
    if ! git ls-remote --tags origin "refs/tags/$tag" | grep -q "refs/tags/$tag"; then
        echo "  Tag '$tag' does not exist on remote - will be pushed."
        different_tags+=($tag)
        continue
    fi
    
    # Compare local and remote tag commit hashes
    local_hash=$(git rev-parse "$tag^{commit}" 2>/dev/null)
    remote_hash=$(git ls-remote --tags origin "refs/tags/$tag" | awk '{print $1}')
    
    # For annotated tags, we need to dereference the remote hash
    if git cat-file -t "$tag" 2>/dev/null | grep -q "tag"; then
        # This is an annotated tag, get the commit it points to on remote
        remote_tag_hash=$remote_hash
        git fetch origin "refs/tags/$tag" --quiet
        remote_hash=$(git rev-parse "FETCH_HEAD^{commit}" 2>/dev/null)
    fi
    
    if [ "$local_hash" != "$remote_hash" ]; then
        echo "  Tag '$tag' differs between local ($local_hash) and remote ($remote_hash) - will be updated."
        different_tags+=($tag)
    fi
done

if [ ${#different_tags[@]} -eq 0 ]; then
    echo "No tags differ between local and remote. Nothing to push."
    exit 0
fi

echo
echo "The following tags differ and will be updated on remote 'origin':"
for tag in "${different_tags[@]}"; do
    echo "  $tag"
done
echo

tags_to_push=(${different_tags[@]})


# Process each tag
for tag in "${tags_to_push[@]}"; do
    echo "Processing tag: $tag"
    
    # Check if tag exists on remote before trying to delete it
    if git ls-remote --tags origin "refs/tags/$tag" | grep -q "refs/tags/$tag"; then
        # Delete the tag from the remote
        echo "  Deleting tag '$tag' from remote.."
        if git push origin --delete "refs/tags/$tag" 2>/dev/null; then
            echo "  Successfully deleted tag '$tag' from remote."
        else
            echo "  Error: Failed to delete tag '$tag' from remote."
            read -p "  Continue with remaining tags? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Operation aborted."
                exit 1
            fi
            continue
        fi
    fi
    
    # Push the local tag to the remote
    echo "  Pushing local tag '$tag' to remote..."
    if git push origin "refs/tags/$tag"; then
        echo "  Successfully pushed tag '$tag' to remote."
    else
        echo "  Error: Failed to push tag '$tag' to remote."
        read -p "  Continue with remaining tags? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation aborted."
            exit 1
        fi
    fi
    echo
done

echo "Tag update complete."
echo "All specified tags have been updated on remote."

