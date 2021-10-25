# API

## GENERAL:

The folder ./websites/ is statically served.

### GET /
###### RESPONSE 
``./index.html``


### GET /viewer/:username
###### RESPONSE 
``./viewer.html``


### POST /login
###### REQUEST 
`` {"username": username_string} ``

###### RESPONSE 
Codes: ``200`` OR ``400``

---
## VIEWER:


### POST /viewer/tabledata
###### REQUEST 
`` {"username": username_string} ``

###### RESPONSE 
```jsonc
[[Location, isChecked, isDisabled, Occupant, Date, Details, Dist, Pos, ID], ...]
```


### POST /viewer/tabledata-v2

You get the table data from this.

###### REQUEST 
`` {"username": username_string} ``


###### RESPONSE 
```jsonc
[{
	"loc": Location, //string: name of the location
	"checked": isChecked, //bool: whether button was checked
	"disabled": isDisabled, //bool: whether this user can check it or not
	"occupancy": OccupantName, //string: who checked the button
	"date": Date, //string: date when it was checked
	"details": Details, //string: small details about the location
	"dist": Dist, //string: distance 
	"id": ID //string: unique id of the place
}, ...]
```


### POST /viewer/tablesubmit

You submit the changes to this.

###### REQUEST 
```jsonc 
{
	"username": username, //string
	"pos": {
		"latitude": geo_latitude, //number
		"longitude": geo_longitude //number
	},
	"data": [
		{
			"name": location_name, //string: name of the location
			"value": checked, //bool: whether the location was checked or not on the client
		},
		...
	]
} 
```


###### RESPONSE 
``Success`` Code: ``200``

---
## PHOTOS:


### GET /photos/:locid
###### RESPONSE 
``./photosviewer.html``


### POST /photos/:locid/:animalname

Send a photo file to be added. If the animal doesn't exist, it'll be created.

###### REQUEST 
```JS
let formData = new FormData();
formData.append("photo", fileinput.files[i]);
await axios.request({
	method: "POST",
	url:`https://verbipati.org/photos/${locname}/${aniname}`,
	data: formData,
)}
```

###### RESPONSE 
Code: ``200`` or some error


### DELETE /photos/:locid/:animalname

Deletes all the photos of the animal and the animal folder.

###### RESPONSE 
Code: ``200`` or some error


### DELETE /photos/:locid/:animalname/:photoname

Deletes a specific photo of the animal.

###### RESPONSE 
Code: ``200`` or some error


### POST /photosmeta/:locid

Gets the meta data of a location.

###### RESPONSE 
```JSONc
{
	"location_name": {
		"animal_name":["someimage.png", "JH0SWGSwsd.jpg", ...]
	}
}
```

### GET /photos/:locid/:animalname/:animalphoto

Responds with the full resolution photo of the animal.

##### RESPONSE
full resolution image file

### GET /minphotos/:locid/:animalname/:animalphoto

Responds with the low resolution photo of the animal. The resolution is automatically shrunk by the server when the full resolution image is sent. One side of the low resolution image is a maximum of 300 pixels like a thumbnail.

##### RESPONSE
low resolution image file

