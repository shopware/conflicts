#!/usr/bin/env bash

# Script to retag if composer.[tagname].json differs from the original composer.json at that tag.
# Also handles creating tags that don't exist yet.

# Ensure jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq (e.g., brew install jq) and try again."
    exit 1
fi

# Ensure we are in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not a git repository. Please run this script from the root of your git repository."
    exit 1
fi

set -e

# Get current branch to switch back to later
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Temporary directory for git show output
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT # Cleanup on exit

for local_composer_file in composer.*.json; do
    if [[ -f "$local_composer_file" ]]; then
        # Extract tag from filename (e.g., composer.0.1.0.json -> 0.1.0)
        tag_name=$(echo "$local_composer_file" | sed -E 's/composer\.(.*)\.json/\1/')

        echo "Processing tag: $tag_name"

        # Check if tag exists
        if ! git show-ref --tags --quiet --verify -- "refs/tags/$tag_name"; then
            echo "  Tag '$tag_name' does not exist. Creating it..."
            
            # Check if temp branch exists and delete it if it does
            if git show-ref --verify --quiet refs/heads/temp-tag-$tag_name; then
                echo "  Temporary branch 'temp-tag-$tag_name' already exists. Removing it first."
                git branch -D "temp-tag-$tag_name" || {
                    echo "  Failed to delete temporary branch. Skipping this tag."
                    continue
                }
            fi
            
            # Create a temporary branch
            git checkout -b "temp-tag-$tag_name" HEAD || {
                echo "  Failed to create temporary branch. Skipping this tag."
                git checkout "$current_branch"
                continue
            }

            # Copy the composer.X.Y.Z.json to composer.json
            cp "$local_composer_file" composer.json
            
            # Commit the change
            git add composer.json
            git commit -m "Create tag $tag_name with composer.json"
            
            # Create the tag on this commit
            git tag -a "$tag_name" -m "Create tag $tag_name"
            
            # Go back to original branch and clean up
            git checkout "$current_branch"
            git branch -D "temp-tag-$tag_name" || echo "  Warning: Failed to delete temporary branch 'temp-tag-$tag_name'"
            
            echo "  Tag '$tag_name' created successfully."
            continue
        fi

        # Get the original composer.json content from the tag
        original_composer_content_file="$temp_dir/composer_original_$tag_name.json"
        if ! git show "$tag_name:composer.json" > "$original_composer_content_file" 2>/dev/null; then
            echo "  WARNING: Could not retrieve composer.json for tag '$tag_name'. Skipping."
            continue
        fi

        # Compare the local composer.[tag].json with the original one from the tag
        # Using jq to normalize JSON for a more robust comparison (ignores formatting differences)
        if ! jq --sort-keys . "$local_composer_file" > "$temp_dir/local_composer_normalized.json" 2>/dev/null; then
            echo "  ERROR: Invalid JSON in '$local_composer_file'. Skipping."
            continue
        fi
        if ! jq --sort-keys . "$original_composer_content_file" > "$temp_dir/original_composer_normalized.json" 2>/dev/null; then
            echo "  ERROR: Invalid JSON in original composer.json for tag '$tag_name'. Skipping."
            continue
        fi

        if ! diff -q "$temp_dir/local_composer_normalized.json" "$temp_dir/original_composer_normalized.json" > /dev/null; then
            echo "  Difference found for tag '$tag_name'. Proceeding with retagging."

            # Get the commit hash the original tag pointed to
            original_commit_hash=$(git rev-parse "$tag_name^{commit}")
            if [ -z "$original_commit_hash" ]; then
                echo "    ERROR: Could not find commit for tag '$tag_name'. Skipping."
                continue
            fi
            echo "    Original commit for tag '$tag_name': $original_commit_hash"

            # Check if the tag is annotated or lightweight
            tag_object_type=$(git cat-file -t "$tag_name" 2>/dev/null)
            is_annotated=false
            if [ "$tag_object_type" == "tag" ]; then
                is_annotated=true
                original_tag_message=$(git cat-file tag "$tag_name" | sed -n '/^$/,$p' | tail -n +2) # Get message after first blank line
                original_tagger_info=$(git for-each-ref "refs/tags/$tag_name" --format='%(taggername) %(taggeremail) %(taggerdate:raw)')
                echo "    Tag '$tag_name' is an annotated tag."
            else
                echo "    Tag '$tag_name' is a lightweight tag."
            fi

            # Create a new commit based on the original commit, but with the updated composer.json
            # This involves:
            # 1. Checking out the original commit (detached HEAD)
            # 2. Replacing composer.json
            # 3. Committing the change
            # 4. Getting the new commit hash

            echo "    Creating new commit with updated composer.json..."
            # Store current HEAD to avoid issues if it's a branch we are on
            original_head_ref=$(git symbolic-ref -q HEAD || git rev-parse HEAD)

            local_composer_content=$(cat "$local_composer_file")

            git checkout "$original_commit_hash" --quiet
            echo "$local_composer_content" > "composer.json"
            git add composer.json
            # Preserve original author and committer if possible, otherwise use current user
            # This is a bit complex, ideally you'd want to reuse the original author/committer.
            # For simplicity, this script will use the current user for the new commit.
            # A more advanced script could try to parse and reuse original author/committer info.
            git commit -m "Update composer.json for tag $tag_name (automated retag)" --quiet
            new_commit_hash=$(git rev-parse HEAD)
            echo "    New commit created: $new_commit_hash"

            # Go back to original HEAD (branch or detached commit)
            if [[ "$original_head_ref" == refs/heads/* ]]; then
                git checkout "${original_head_ref#refs/heads/}" --quiet
            else
                git checkout "$original_head_ref" --quiet
            fi

            # Delete the old local tag
            echo "    Deleting old local tag '$tag_name'."
            git tag -d "$tag_name"

            # Create the new tag pointing to the new commit
            if $is_annotated; then
                echo "    Creating new annotated tag '$tag_name' pointing to $new_commit_hash."
                # Attempt to re-use tagger info. This is a simplified approach.
                # A robust solution would need to parse and re-apply tagger info correctly.
                GIT_COMMITTER_NAME=$(echo "$original_tagger_info" | awk '{print $1}')
                GIT_COMMITTER_EMAIL=$(echo "$original_tagger_info" | awk '{print $2}')
                GIT_COMMITTER_DATE=$(echo "$original_tagger_info" | awk '{print $3 " " $4}')

                if [[ -n "$GIT_COMMITTER_NAME" && "$GIT_COMMITTER_NAME" != "(null)" ]]; then
                    # If original tagger info is parsable
                    GIT_COMMITTER_NAME="$GIT_COMMITTER_NAME" \
                    GIT_COMMITTER_EMAIL="$GIT_COMMITTER_EMAIL" \
                    GIT_COMMITTER_DATE="$GIT_COMMITTER_DATE" \
                    git tag -a "$tag_name" -m "Automated retag: Updated composer.json for $tag_name. Original message was:
$original_tag_message" "$new_commit_hash"
                else
                    # Fallback if tagger info couldn't be parsed well
                    git tag -a "$tag_name" -m "Automated retag: Updated composer.json for $tag_name. Original message was:
$original_tag_message" "$new_commit_hash"
                fi
            else
                echo "    Creating new lightweight tag '$tag_name' pointing to $new_commit_hash."
                git tag "$tag_name" "$new_commit_hash"
            fi
            echo "    Tag '$tag_name' successfully updated locally to point to new commit $new_commit_hash."
        else
            echo "  No difference found for tag '$tag_name'. Skipping."
        fi
        echo # Newline for readability
    fi
done

# Switch back to the original branch
if [[ "$current_branch" != "HEAD" ]]; then # HEAD indicates detached state
    git checkout "$current_branch" --quiet
else
    echo "Was in a detached HEAD state. Current HEAD is $(git rev-parse HEAD)."
fi

echo "
To push the tags to the remote repository, run:
git push origin --tags
"