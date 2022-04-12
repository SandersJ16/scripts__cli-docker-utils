#!/bin/bash

contains () {
  local e match="$search_name"
  shift
  for e; do [[ "$e" = "$match" ]] && return 0; done
  return 1
}

search_name="$1"

#----------------------------------------------------------------------------------------------------------
# Check if a container with the supplied name already exists if it does exec into it
#----------------------------------------------------------------------------------------------------------

containers=($(docker container ps --format '{{.Names}}'))
if contains "$search_name" "${containers[@]}"; then
    echo "Found existing container named '$search_name'"
    docker exec "${@:2}" -it "$search_name" /bin/bash -l
    exit 0
fi

#----------------------------------------------------------------------------------------------------------
# Check if a Image with this name exists, if it does create a container using this image and exec into it
#----------------------------------------------------------------------------------------------------------

# If the name doesn't have a : in it then match on all tags where image repository matches $search_name
if [[ "$search_name" = *":"* ]]; then
    image_reference="$search_name"
else
    image_reference="$search_name:*"
fi
images=($(docker image ls --format="{{.Repository}}:{{.Tag}}" --filter='dangling=false' --filter="reference=$image_reference"))

# If we matched multiple images print a message teling the user to be more specific
if  [[ "${#images[@]}" -gt 1 ]]; then
    echo "Multiple $search_name images found. Please specify a version"
    # Print all found version of the image
    printf '%s\n' "${images[@]}"
    exit 1
fi

# If we found 1 image matching that name use it
if [[ "${#images[@]}" -eq 1 ]]; then
    image_name="${images[0]}"
else
# Otherwise check if this image is a valid Image ID and use that if it is
    docker image inspect "$search_name" > /dev/null 2>&1
    status=$?
    if [ $status -eq 0 ]; then
        image_name="$search_name"
    fi
fi

# If we found an images create a new instance of a container for that image
if [ ! -z ${image_name+x} ]; then
    # Create a unique name for the container image
    temp_instance_index=1
    while contains "temp_instance_$temp_instance_index" "${containers[@]}"; do
      temp_instance_index=$(($temp_instance_index + 1))
    done

    echo "Found Image named '$image_name', creating container temp_instance_$temp_instance_index using image"
    docker run "${@:2}" --name "temp_instance_$temp_instance_index" -ti --rm "$image_name" /bin/bash
    exit 0
fi

echo "Couldn't find Container or Image called '$search_name'"
exit 1
