import requests
import json
from PIL import Image
from io import BytesIO
import base64
import time

# URL of your local server
url = "http://3.90.2.238:5000/generate"

# Example prompt and parameters
data = {
    "prompt": """Given this image style: A whimsical and richly detailed style inspired by classic storybook illustrations. It combines realism in character rendering with a fantastical and vibrant color palette that echoes the magical elements of the story. Expressions and environments are slightly exaggerated to enhance the dynamic and magical atmosphere, suitable for a young audience.. 
    Generate an image for the following description: a sunlit hogwarts courtyard bustling with students saying goodbyes and packing for their summer vacations. harry potter, in robes showing signs of wear, exhibits a mix of relief and pride. dobby, with an anxious yet empowered expression, stands free alongside him. ron weasley, in slightly disheveled clothes suitable for adventures, reflects both determination and urgency. gilderoy lockhart, with colorful yet dusted robes, appears slightly out of his usual composed character. amidst them, lucius malfoy stands tall with impeccably combed pale blond hair and dark, expensive robes, symbolizing his authoritative presence. nearby, dumbledore, with his deep-hued, elegant robes, watches over with a calm, grandfatherly appearance. the courtyard, rendered in whimsical, richly detailed storybook style with vibrant colors, captures the magical elements and youthful excitement. the warm lighting and ambient sounds of farewells and laughter evoke a sense of closure and anticipation for the next academic year.""",
    "inference_steps": 50,
    "guidance_scale": 7.5,
    "max_sequence_length": 512
}

start_time = time.time()  # Start time for performance measurement
# Send POST request to the server
response = requests.post(url, json=data)
print(f"Request sent. Time taken: {time.time() - start_time:.2f} seconds")

# Check if the response is successful
if response.status_code == 200:
    response_json = response.json()
    if 'image_base64' in response_json:
        # Decode the base64 image string
        img_data = base64.b64decode(response_json['image_base64'])
        img = Image.open(BytesIO(img_data))
        img.show()  # Show the image

    else:
        print("Error: Image data not found in response.")

else:
    print(f"Error: {response.status_code} - {response.text}")
