#!/bin/bash
script_start_time=$SECONDS

# ----------------
# VERIFY INPUTS
# ----------------

# Check if the user has provided a library folder name if copy_readme_and_license_to_include: is true
if [[ "$INPUT_COPY_README_AND_LICENSE_TO_INCLUDE" == "true" && -z "$INPUT_LIB_FOLDER_NAME" ]]; then
    echo "You must provide a library folder name if copy_readme_and_license_to_include is true" >&2
    echo "You must provide a library folder name if copy_readme_and_license_to_include is true"
    # Add to Workflow summary
    echo "# ::error::You must provide a library folder name if copy_readme_and_license_to_include is true" >> $GITHUB_STEP_SUMMARY
    exit 102502 # This is the string "pros-build" turned into int values, added together, and then multiplied by 10 plus the error code at the end. This is to hopefully avoid conflicts with other error codes.
fi

# ------------
# ECHO LICENSE
# ------------
echo "::group::License"
cat /LICENSE
echo "::endgroup::"

# ----------------
# SETTING VARIABLES
# ----------------

set -e # Exit on error

git config --global --add safe.directory /github/workspace


# ----------------
# CHECK IF TEMPLATE
# ----------------
echo "::group::Checking if this is a template"

template=$(awk -F'=' '/^IS_LIBRARY:=/{print $2}' Makefile)
if [ "$template" == "1" ]; then
    echo "is template"
else
    echo "is not template"
fi
echo "template=$template" >> $GITHUB_OUTPUT

echo "::endgroup::"


# ----------------
# GET PROJECT INFO
# ----------------
echo "::group::Getting project info"

if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
    # Fetch the head SHA directly from the PR API
    API_URL="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$GITHUB_PR_NUM"
    echo "API URL: $API_URL"
    API_RESPONSE=$(wget -O- --quiet "$API_URL")
    if [ $? -ne 0 ]; then
        echo "Error fetching data from GitHub API"
        exit $?
    fi
    echo "API Response: $API_RESPONSE"
    sha=$(echo "$API_RESPONSE" | jq -r '.head.sha' | head -c 6)

else
    # Use the commit SHA after the event
    sha=$(git rev-parse HEAD | head -c 6)
fi



function get_sha() {
    echo "sha=$sha" >> $GITHUB_OUTPUT
    echo "SHA found: $sha"
}

function get_version() {
    version=$(awk -F'=' '/^VERSION:=/{print $2}' Makefile)
    echo "Version found: $version"
    echo "version=$version" >> "$GITHUB_OUTPUT"
    echo $version >> "version.txt"
}

function get_library_name() { 
    library_name=$(awk -F'=' '/^LIBNAME:=/{print $2}' Makefile)
    echo "library_name=$library_name" >> "$GITHUB_OUTPUT"
    echo "Library name found: $library_name"
    echo $library_name >> "library_name.txt"
}

get_sha &
get_version &
get_library_name &
wait

version=$(cat version.txt)
rm version.txt
library_name=$(cat library_name.txt)
rm library_name.txt

echo "Version before setting postfix: $version"
echo "SHA before setting postfix: $sha"

if [ "$INPUT_NO_COMMIT_HASH" == "true" ]; then
    postfix="${version}"
else
    postfix="${version}+${sha}"
fi
echo "Postfix after setting: $postfix"
echo "postfix=$postfix" >> "$GITHUB_OUTPUT"

name="$library_name@$postfix"
echo "name=$name" >> "$GITHUB_OUTPUT"
echo "Name found: $name"

echo "::endgroup::"
# ----------------
# BUILDING PROJECT
# ----------------
# Pause errors
set +e
pros make clean
ERR_OUTPUT=$(mktemp)
STD_OUTPUT=$(mktemp)
# Set IS_LIBRARY to 0 to build the project if $template is 1
if (($template == 1)); then
    echo "::group::Building ${name}"
    echo "Setting IS_LIBRARY to 0"
    sed -i "s/^IS_LIBRARY:=.*\$/IS_LIBRARY:=0/" Makefile
fi


if [[ "$INPUT_MULTITHREADING" == "true" ]]; then
    echo "Multithreading is enabled"
    start_build_time=$SECONDS
    make quick -j 2> $ERR_OUTPUT | tee $STD_OUTPUT
    build_time=$((SECONDS - $start_build_time))
else
    echo "Multithreading is disabled"
    start_build_time=$SECONDS
    make quick 2> $ERR_OUTPUT | tee $STD_OUTPUT
    build_time=$((SECONDS - $start_build_time))
fi


if (($template == 1)); then
    echo "Setting IS_LIBRARY back to 1"
    sed -i "s/^IS_LIBRARY:=.*\$/IS_LIBRARY:=1/" Makefile
    echo "::endgroup::"
fi

STD_EDITED_OUTPUT=$(mktemp)
# Remove ANSI color codes from the output
sed -e 's/\x1b\[[0-9;]*m//g' $STD_OUTPUT > $STD_EDITED_OUTPUT

if [ -s "$ERR_OUTPUT" ]; then
    error_output=$(cat "$ERR_OUTPUT")
    norm_output=$(cat "$STD_EDITED_OUTPUT")
    echo "# 🛑 Build Failed" >> $GITHUB_STEP_SUMMARY
    echo "#### 📄 Error Output" >> $GITHUB_STEP_SUMMARY
    echo "Build failed in $build_time seconds" >> $GITHUB_STEP_SUMMARY
    echo "Total Build Script Runtime: $(($SECONDS - $script_start_time)) seconds" >> $GITHUB_STEP_SUMMARY
    echo "<details><summary>Click to expand</summary>" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
    echo "$norm_output" >> $GITHUB_STEP_SUMMARY
    echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
    echo "</details>" >> $GITHUB_STEP_SUMMARY
    exit 1
fi

# -----------------
# CREATING TEMPLATE
# -----------------

set -e # Exit on error

if (($template == 1)); then
echo "::group::Updating Makefile"

sed -i "s/^VERSION:=.*\$/VERSION:=${postfix}/" Makefile

cat Makefile

echo "::endgroup::"



echo "::group::Creating ${name} template"

pros make template

echo "::endgroup::"


# --------------
# UNZIP TEMPLATE
# --------------

echo "::group::Unzipping template"

unzip -o $name -d template # Unzip the template

echo "::endgroup::"


fi 

# ---------------------------
# ADDING VERSION, LICENSE
# AND README TO THE TEMPLATE
# FOLDER
# ---------------------------
if [["$INPUT_COPY_README_AND_LICENSE_TO_INCLUDE" == "true"]]; then
    if [[$INPUT_LIB_FOLDER_NAME != ""]]; then
        echo "::group::Adding version, license and readme to the template folder"
        cp version.txt template/$INPUT_LIB_FOLDER_NAME/version.txt
        cp LICENSE template/$INPUT_LIB_FOLDER_NAME/LICENSE
        cp README.md template/$INPUT_LIB_FOLDER_NAME/README.md
        echo "::endgroup::"
    else
        echo "::group::Adding version, license and readme to the template folder"
        echo "Error: You must provide a library folder name if copy_readme_and_license_to_include is true" >&2
        echo "::endgroup::"
        # exit with an error code of 2, representing the error code for missing library folder name
        # Redundant, but just in case
        exit 102502 # This is the string "pros-build" turned into int values, added together, and then multiplied by 10 plus the error code at the end (error code 3). This is to hopefully avoid conflicts with other error codes.
    fi
fi
# -----------
# JOB SUMMARY
# -----------
norm_output=$(cat "$STD_EDITED_OUTPUT")
echo "# ✅ Build Completed" >> $GITHUB_STEP_SUMMARY
echo "Build completed in $build_time seconds" >> $GITHUB_STEP_SUMMARY
echo "Total Build Script Runtime: $(($SECONDS - $script_start_time)) seconds" >> $GITHUB_STEP_SUMMARY
echo "## 📝 Library Name: ${library_name} @ ${version}" >> $GITHUB_STEP_SUMMARY
echo "### 🔐 SHA: ${sha}" >> $GITHUB_STEP_SUMMARY
if (($template == 1)); then
echo "### 📁 Artifact Name: ${name}" >> $GITHUB_STEP_SUMMARY
fi
echo "***" >> $GITHUB_STEP_SUMMARY
echo "#### 📄 Output from Make" >> $GITHUB_STEP_SUMMARY
echo "<details><summary>Click to expand</summary>" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
echo "$norm_output" >> $GITHUB_STEP_SUMMARY
echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
echo "</details>" >> $GITHUB_STEP_SUMMARY