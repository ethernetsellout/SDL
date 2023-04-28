#!/bin/bash

# Set the folder where the XML files are located
xml_folder="../../wayland-protocols"

# Loop through all XML files in the folder
for xml_file in "$xml_folder"/*.xml; do
    # Extract the protocol name from the file name
    protocol_name=$(basename "$xml_file" .xml)

    # Run wayland-scanner on the XML file and output the header
    wayland-scanner client-header "$xml_file" "${protocol_name}-client-protocol.h"
done

