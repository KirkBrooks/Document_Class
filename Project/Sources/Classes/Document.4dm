/*  Document class
 Created by: Kirk as Designer, Created: 03/22/22, 14:03:40
 ------------------
Wrapper for 4D.File that provides functions for using classic
document methods as well.

 */
Class constructor($input : Variant)
	If (Count parameters=0)
		This._file:=Null
	Else 
		This.set_file($input)
	End if 
	
	//
	This._docRef:=0
	This._docMode:=0  // 0=RW, 1=Write, 2=Read Only
	This._docErr:=""
	This._error:=""
	
	//  options for selecting a document
	This._select:=New object(\
		"defaultPath"; System folder(Desktop); \
		"message"; "Select the document: "; \
		"docTypes"; "*"; \
		"allowAlias"; True; \
		"nameEntry"; True; \
		"packageOpen"; True; \
		"packageSelect"; True; \
		"sheetWindow"; True)
	
	//mark:-  error handling
Function install_errorIgnore($method : Text)
/* allows you to install an ignore error handler
some functions will wrap errors for smoother processin
*/
	This._errIgnoreMethod:=$method
	
Function _errIgnore
	error:=0  //  clear 4D error register
	If (This._errIgnore#"")
		This._onErrCallmethod:=Method called on error  //  whatever the current error handler is
		ON ERR CALL(This._errIgnoreMethod)
	End if 
	
Function _clearErrIgnore
	ON ERR CALL(This._onErrCallmethod)
	
	//MARK:-
Function set_file($input : Variant)
	
	This.close_document()
	
	Case of 
		: (Value type($input)=Is object)  //  4D file object or Document class
			Case of 
				: (OB Instance of($input; cs.Document))
					This._file:=$input._file
					
				: (OB Instance of($input; 4D.File))
					This._file:=$input
			End case 
			
		: (Value type($input)=Is longint)
			This._file:=File($input)
			
		: (Value type($input)=Is text)  //  platform or posix
			
			If (Position("/"; $input)>0)
				This._file:=File($input; fk posix path)
			Else   //  assume it's platform
				This._file:=File($input; fk platform path)
			End if 
			
		Else 
			This._file:=Null
			
	End case 
	
	This._calcHash()
	This._setKind()
	
Function select($params : Object)->$selected : Boolean
/* True if document selected.
  Doesn't allow multiple files.
params: {
"directory": (Text) Directory access path to display by default in the document selection dialog box, or
             Empty string to display default user folder (“My documents” under Windows, “Documents” under Mac OS), or
             Number of the memorized access path
"fileTypes": (Text) List of types of documents to filter, or "*" to not filter documents
"title":     (Text) Title of the selection dialog box
*/
	var $options_l : Integer
	var $key; $path : Text
	ARRAY TEXT($aDocs; 0)
	
	If (Count parameters=1)
		For each ($key; $params)
			This._select[$key]:=$params[$key]
		End for each 
	End if 
	
	$options_l:=Num(This._select.allowAlias)*Allow alias files
	$options_l+=Num(This._select.packageOpen)*Package open
	$options_l+=Num(This._select.packageSelection)*Package selection
	$options_l+=Num(This._select.sheetWindow)*Use sheet window
	
	If (Select document(\
		This._select.defaultPath; \
		This._select.docTypes; \
		This._select.message; \
		$options_l; $aDocs)#"")
		
		This.set_file($aDocs{1})
		
		//  update the default path
		If (This.exists)
			This._select.defaultPath:=This.file.parent.platformPath
		End if 
		
		$selected:=True
		
	End if 
	
Function duplicate->$file : cs.Document
	//  duplicates the file in place
	If (This.exists)
		$file:=cs.Document.new(This.copyTo(This.parent; This._incrementName()))
	End if 
	
Function getJSON()->$object : Object
	//  if the extension is JSON parse it
	If (This.exists) && (This.extension=".json")
		$object:=JSON Parse(This.getText())
	End if 
	
Function get4Dfile()->$file : 4D.File
	$file:=This._file
	
	//MARK:-  picture functions
Function _pictureInfo()->$info : Object
	var $picture : Picture
	var $width; $height : Integer
	var $ratio : Real
	var $int : Integer
	
	If (This.exists) && (This.kind="image")
		$picture:=This.getPicture()
		
		PICTURE PROPERTIES($picture; $width; $height)
		
		This._picInfo:=New object(\
			"width"; $width; \
			"height"; $height)
		
/* width & height are measured in terms of the original image. If the image
has been rotated that may have changed. If the TIFF orientation meta data is included
it will indicate if there has been a rotation.
Values  1-4 = no change in orientation (may have been flipped or mirrored)
        5-8 = rotation
*/
		GET PICTURE METADATA($picture; TIFF orientation; $int)
		Case of 
			: ($width>($height*1.05))  //  width is 5% greater than height
				If ($int<=4)  //
					This._picInfo.orientation:="landscape"
				Else   //  it's rotated
					This._picInfo.orientation:="portrait"
				End if 
				
			: ($height>($width*1.05))  //  height is 5% greater than width
				If ($int<=4)  //
					This._picInfo.orientation:="portrait"
				Else   //  rotated
					This._picInfo.orientation:="landscape"
				End if 
				
			Else 
				This._picInfo.orientation:="square"
				
		End case 
		
	End if 
	
Function getPicture()->$picture : Picture
	If (This.exists) && (This.kind="image")
		BLOB TO PICTURE(This.getContent(); $picture)
	End if 
	
Function get pictureWidth->$width : Integer
	If (This.exists) && (This.kind="image")
		$width:=This._picInfo.width
	End if 
	
Function get pictureHeight->$height : Integer
	If (This.exists) && (This.kind="image")
		$height:=This._picInfo.height
	End if 
	
Function get pictureOrientation->$orientation : Text
	If (This.exists) && (This.kind="image")
		$orientation:=This._picInfo.orientation
	End if 
	
	//MARK:- classic document functions
/*  functions for working with Open document, Append document, Close document
SEND PACKET and RECEIVE PACKET
Always use .select() to choose a document to open.
	
The send, recieve and append commands will open the document in
read only if it is not open already. $closeDoc means the document
will be closed after the operation.
	
These commands are wrapped in an error handler to filter the
file handling errors.
*/
Function get docRef->$docRef : Time
	//  can't store a time ref in the class
	$docRef:=(This.isDocOpen) ? Time(This._docRef) : ?00:00:00?
	
Function get isDocOpen->$isDocOpen : Boolean
	$isDocOpen:=Time(This._docRef)#?00:00:00?
	
Function get isDocError->$isErr : Boolean
	$isErr:=This._docErr#""
	
Function get docErrText->$text : Text
	$text:=String(This._docErr)
	
Function new_document($leaveOpen : Boolean)
	//  allows user to create a document.
	// $leaveOpen means you will use the classic SEND/RECEIVE PACKET functions
	var $docRef : Time
	
	This.close_document()
	
	$docRef:=Create document("")
	
	If (OK=1)
		CLOSE DOCUMENT($docRef)
		This.set_file(document)
	End if 
	
Function open_document($mode : Integer)->$docRef : Time
	//  opens the document. Must be defined.
	If (This.isDefined)
		This._docErr:=""
		
		If (This.isDocOpen=False) && ($mode#This._docMode)
			This.close_document()
		End if 
		
		This._docMode:=Num($mode)
		
		This._errIgnore()
		
		If (This.exists)
			$docRef:=Open document(This.platformPath; This.extension; This._docMode)
		Else 
			$docRef:=Create document(This.platformPath; This.extension)
		End if 
		
		This._clearErrIgnore()
		This._checkDocErr()
		
		If (Not(This.isDocError))
			This._docRef:=$docRef
		End if 
		
	End if 
	
Function close_document
	If (This.isDocOpen) && (Not(This.isDocError))
		CLOSE DOCUMENT(Time(This._docRef))
		This._calcHash()
		This._setKind()
	End if 
	
	This._docRef:=0
	This._docMode:=0
	This._docErr:=""
	
Function send_packet($content : Variant; $append : Boolean; $closeDoc : Boolean)
	//  $content is text or blob
	If (This.isDefined)
		
		If (Not(This.isDocOpen))
			This.open_document()  //  opens doc in read write
		End if 
		
		If ($append) && (Not(This.isDocError))
			This.set_document_position(This.size)
		End if 
		
		If (Not(This.isDocError))
			
			This._errIgnore()
			SEND PACKET(Time(This._docRef); $content)
			This._clearErrIgnore()
			This._checkDocErr()
			
		End if 
		
		If ($closeDoc) && (Not(This.isDocError))
			This.close_document()
		End if 
		
	End if 
	
Function receive_packet_text($delimiter : Variant)->$content : Text
	//  set the start position before calling
	//  $delimiter is either a string or number of chars
	$content:=This._receivePacket($delimiter; "text")
	
Function receive_packet_blob($delimiter : Variant)->$content : Blob
	//  set the start position before calling
	//  $delimiter is either a string or number of chars
	$content:=This._receivePacket($delimiter; "blob")
	
Function _receivePacket($delimiter : Variant; $kind : Text)->$content : Variant
	var $textContent : Text
	var $blobContent : Blob
	
	If (This.isDefined) && (This.isDocOpen)
		
		If (Not(This.isDocError))
			
			This._errIgnore()
			
			If ($delimiter=Null)  //  must have some delimiter
				// get the remainder of the document
				$delimiter:=This.size-This.get_document_position()
			End if 
			
			Case of 
				: ($kind="text")
					RECEIVE PACKET(Time(This._docRef); $textContent; $delimiter)
					$content:=$textContent
					
				: ($kind="blob")
					RECEIVE PACKET(Time(This._docRef); $blobContent; $delimiter)
					$content:=$blobContent
					
			End case 
			
			This._clearErrIgnore()
			This._checkDocErr()
		End if 
		
	End if 
	
Function get_document_position->$position : Integer
	$position:=This.isDocOpen ? Get document position(Time(This._docRef)) : 0
	
Function set_document_position($offset : Integer)
	If (This.isDocOpen)
		SET DOCUMENT POSITION(Time(This._docRef); $offset)
	End if 
	
	//MARK:- private functions
Function _calcHash()
	var $blob : Blob
	
	If (This.exists)
		$blob:=This.getContent()
		This.hash:=Generate digest($blob; MD5 digest)
		SET BLOB SIZE($blob; 0)
		
	Else 
		This.hash:=""
		
	End if 
	
Function _setKind()
	Case of 
		: (This._file=Null)
			This.kind:=""
			
		: (This.extension=".json")
			This.kind:="json"
			
		: (This.extension=".docx")
			This.kind:="word"
			
		: (This.extension=".xlsx")
			This.kind:="excel"
			
		: (This.extension=".jpg") | (This.extension=".tif@") | (This.extension=".jpeg") | (This.extension=".png")
			This.kind:="image"
			This._pictureInfo()
		Else 
			This.kind:="document"
	End case 
	
Function _incrementName->$name : Text
/*  Purpose: returns a file name incremented by 1
for this file
*/
	var $count : Integer
	
	If (This._file#Null)
		$count:=1
		$name:=This.fullName
		
		While (This.parent.file($name).exists)
			$name:=This.name+" ("+String($count)+")"+This.extension
			$count:=$count+1
		End while 
		
	End if 
	
Function _checkDocErr
	//  checks 4D error  call this after   this._errIgnore()
	If (error#0)
		//  Error, Error method, Error line, Error formula  
		This._docErr:=Error method+": line "+String(error line)+"; "+error formula+",  #"+String(error)
		
		This._showAlert("There was an error:\r\r"+This._docErr)
	Else 
		This._docErr:=""
	End if 
	
Function _showAlert($message : Text)
	If (Application type#4D Server)
		ALERT($message)
	End if 
	
	//MARK:-  4D file functions and properties
Function get isDefined() : Boolean
	return Bool(This._file#Null)
	
Function get exists() : Boolean
	return This._file ? Bool(This._file.exists) : False
	
Function get extension : Text
	// the extension of the file name (if any)
	return This._file ? String(This._file.extension) : ""
	
Function get fullName : Text
	// the full name of the file, including its extension (if any)
	return This._file ? String(This._file.fullName) : ""
	
Function get hidden : Boolean
	// true if the file is set as "hidden" at the system level
	return This._file ? This._file.hidden : False
	
Function get isAlias : Boolean
	// true if the file is an alias, a shortcut, or a symbolic link
	return This._file ? This._file.isAlias : False
	
Function get isFile : Boolean
	// always true for a file
	return This._file ? This._file.isFile : False
	
Function get isFolder : Boolean
	// always false for a file
	return This._file ? This._file.isFolder : False
	
Function get isWritable : Boolean
	// true if the file exists on disk and is writable
	return This._file ? This._file.isWriteable : False
	
Function get modificationDate : Date
	// the date of the file's last modification
	return This._file ? This._file.modificationDate : !00-00-00!
	
Function get modificationTime : Time
	// the time of the file's last modification
	return This._file ? This._file.modificationTime : ?00:00:00?
	
Function get creationDate : Date
	// the creation date of the file
	return This._file ? This._file.creationDate : !00-00-00!
	
Function get creationTime : Time
	// the creation time of the file
	return This._file ? This._file.creationTime : ?00:00:00?
	
Function get name : Text
	// the name of the file without extension (if any)
	return This._file ? This._file.name : ""
	
Function get original : 4D.File
	// the target element for an alias, a shortcut, or a symbolic link file
	return This._file ? This._file.original : Null
	
Function get parent : 4D.Folder
	// the parent folder object of the file
	return This._file ? This._file.parent : Null
	
Function get path : Text
	// the POSIX path of the file
	return This._file ? This._file.path : ""
	
Function get platformPath : Text
	// the path of the file expressed with the current platform syntax
	return This._file ? This._file.platformPath : ""
	
Function get size : Integer
	return This._file ? This._file.size : 0
	
	//MARK:-  functions
	
Function rename($newName : Text) : cs.Document
	// renames the file with the name you passed in newName and returns the renamed File object
	If (This.exists) & ($newName#"")
		return cs.Document.new(This._file.rename($newName))
	End if 
	
Function getAppInfo() : Object
	// returns the contents of a .exe, .dll or .plist file information as an object
	return This._file ? This._file.getAppInfo() : Null
	
Function getContent()->$content : 4D.Blob
	//  returns a 4D.Blob object containing the entire content of a file
	If (This.exists)
		$content:=This._file.getContent()
	End if 
	
Function getIcon($size : Integer)->$icon : Picture
	// the icon of the file
	If (This.exists)
		$icon:=Count parameters=0 ? This._file.getIcon() : This._file.getIcon($size)
	End if 
	
Function getText($charSetName : Variant; $breakMode : Integer) : Text
	// returns the contents of the file as text
	Case of 
		: (This.exists=False)
			return ""
		: (Count parameters=0)
			return This._file.getText()
		: (Count parameters=1)
			return This._file.getText($charSetName)
		Else 
			return This._file.getText($charSetName; $breakMode)
	End case 
	
Function setAppInfo($info : Object)
	// writes the info properties as information contents of a .exe, .dll or .plist file
	If (This.exists)
		This._file.setAppInfo($info)
	End if 
	
Function setContent($content : Blob)
	// rewrites the entire content of the file using the data stored in the content BLOB
	This._file.setContent($content)
	
Function setText($Text : Text; $charSetName : Variant; $breakMode : Integer)
	// writes text as the new contents of the file
	Case of 
		: (This.isDefined=False)
		: (This.isDocOpen)  //  document is open
			This.send_packet($text)
			
		: (Count parameters=1)
			This._file.setText($Text)
		: (Count parameters=2)
			This._file.setText($Text; $charSetName)
		Else 
			This._file.setText($Text; $charSetName; $breakMode)
	End case 
	
Function copyTo($destinationFolder : 4D.Folder; $newName : Text; $overwrite : Integer)->$newFile : 4D.File
	// copies the File object into the specified destinationFolder
	Case of 
		: (This.exists=False)
			
		: (Count parameters=1)
			$newFile:=This._file.copyTo($destinationFolder)
		: (Count parameters=2)
			$newFile:=This._file.copyTo($destinationFolder; $newName)
		: (Count parameters=3)
			$newFile:=This._file.copyTo($destinationFolder; $newName; $overwrite)
	End case 
	
Function create() : Boolean
	// creates a file on disk according to the properties of the File object
	return (This.exists) ? This._file.create() : False
	
Function createAlias($destinationFolder : 4D.Folder; $aliasName : Text; $aliasType : Integer)->$file : 4D.File
	// creates an alias (macOS) or a shortcut (Windows)
	Case of 
		: (This.exists=False)
		: (Count parameters=1)
			$file:=This._file.createAlias($destinationFolder)
		: (Count parameters=2)
			$file:=This._file.createAlias($destinationFolder; $aliasName)
		Else 
			$file:=This._file.createAlias($destinationFolder; $aliasName; $aliasType)
	End case 
	
Function delete()
	// deletes the file
	If (This.exists)
		This._file.delete()
	End if 
	
Function moveTo($destinationFolder : 4D.Folder; $newName : Text)->$file : 4D.File
	// moves or renames the File object into the specified destinationFolder
	Case of 
		: (This.exists=False)
		: (Count parameters=1)
			$file:=This._file.moveTo($destinationFolder)
		: (Count parameters=2)
			$file:=This._file.moveTo($destinationFolder; $newName)
	End case 
	