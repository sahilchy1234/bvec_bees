#!/bin/bash

# This script fixes the -G flag issue by modifying the build process
echo "Fixing build flags..."

# Find and remove -G flags from all build settings
find /Users/sahilchoudhury/Documents/GitHub/bvec_bees/ios -name "*.xcconfig" -type f -exec sed -i '' 's/-G//g' {} \;

# Also check for any -G flags in the project file
find /Users/sahilchoudhury/Documents/GitHub/bvec_bees/ios -name "project.pbxproj" -type f -exec sed -i '' 's/-G//g' {} \;

echo "Build flags fixed!"
