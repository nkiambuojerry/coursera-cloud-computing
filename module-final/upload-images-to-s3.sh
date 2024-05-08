#!/bin/bash

# Run this script: bash ./upload-images-to-s3.sh $(< ~/arguments.txt)

# S3 commands
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/index.html
# Upload illinoistech.png and rohit.jpg to bucket ${13}

if [ $# = 0 ]
then
  echo "You don't have enough variables in your arugments.txt, you need to pass your argument.txt file..."
  echo "Execute: bash ./upload-images-to-s3.sh $(< ~/arguments.txt)"
  exit 1 
else
    echo "Uploading image: ./Users/user/Documents/coursera-cloud-computing/images/illinoistech.png://${13}..."
    aws s3 cp ./Users/user/Documents/coursera-cloud-computing/images/illinoistech.png://${13}
    echo "Uploaded image: ./Users/user/Documents/coursera-cloud-computing/images/illinoistech.png://${13}..."

    echo "Uploading image: ./Users/user/Documents/coursera-cloud-computing/images/rohit.jpg://${13}..."
    aws s3 cp ./Users/user/Documents/coursera-cloud-computing/images/rohit.jpg://${13}
    echo "Uploaded image: ./Users/user/Documents/coursera-cloud-computing/images/rohit.jpg://${13}..."

    echo "Listing content of bucket: s3://${13}..."
    aws s3 ls s3://${13}

    # Upload ranking.jpg and elevate.webp to bucket ${20}
    echo "Uploading image: ./Users/user/Documents/coursera-cloud-computing/images/elevate.webp to s3://${14}..."
    aws s3 cp ./Users/user/Documents/coursera-cloud-computing/images/elevate.webp s3://${14}
    echo "Uploaded image: ./Users/user/Documents/coursera-cloud-computing/images/elevate.webp to s3://${14}..."

    echo "Uploading image: ./Users/user/Documents/coursera-cloud-computing/images/ranking.jpg://${14}..."
    aws s3 cp ./Users/user/Documents/coursera-cloud-computing/images/ranking.jpg://${14}
    echo "Uploaded image: ./Users/user/Documents/coursera-cloud-computing/images/ranking.jpg://${14}..."

    echo "Listing content of bucket: s3://${14}..."
    aws s3 ls s3://${14}
# End of if
fi
