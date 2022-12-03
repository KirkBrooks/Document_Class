Wrapper for 4D.File
## Document - wrapper for 4D.File

Document provides all the functions of **[4D.File](https://doc.4d.com/4Dv19R6/4D/19-R6/File.301-5910568.en.html)** plus several others for file handling.

### Instantiating

```4d
// instantiate the class
$class:=cs.Document.new()

// you can specify the document
// platform or posix
$class:=cs.Document.new("Macintosh HD:Users:kirk:Desktop:myNewDoc.txt")

// you can pass a 4D.File object
$class:=cs.Document.new(File(Backup history file))

// you can pass another Document class
$class:=cs.Document.new()
$class2:=cs.Document.new($class)
```
Some examples:

### Properties

These are properties of the class beyond the regular **4D.File** properties:

| Property                    | Description                                                  |
| --------------------------- | ------------------------------------------------------------ |
| **hash**: Text              | MD5 hash of contents of the file.                            |
| **kind**: Text              | General kind of file: json, word, excel, image, document     |
| **pictureWidth**: Integer   | If the contents are a picture                                |
| **pictureHeight**: Integer  | If the contents are a picture                                |
| **pictureOrientation**:Text | If the contents are a picture - landscape, portrait, square  |
| **isDefined**: Boolean      | True if the class has a file defined. The file may or may not exist yet. |
| **docRef**: Time            | Document ref of opened document.                             |
| **isDocOpen**: Boolean      | True if the referenced file has been opened with **Open document** |
| **isDocError**: Boolean     | True if there has been an error using the classic document commands. |
| **docErrText**: Text        | Text of the classic document                                 |

The `.hash` property is a simple MD5 hash of the contents. It’s useful for identifying a file by it’s contents rather than the title or size. If two files have the same hash value it is highly likely they have the same contents. 



### Functions

All the functions of **4D.File** are available with the same parameters and results.

|Function|Action|
|--------|------|
|.**set_file** ($input : `Variant`) | Sets the file, that is defines the file this class is based on. |
|**.select** ( $params : `object` )<br />$params {<br />**defaultPath**:text - default = Desktop, <br />**allowAlias**:boolean - default = true, <br />**message**:text - default = true, <br />**packageOpen**:boolean - default = true,  <br />**packageSelection**:boolean - default = true, <br />**sheetWindow**:boolean - default = true, <br />} | Allows user to select a single file. <br />Uses **Select document**. Allows all options for that command _except_ for multiple file selection. |
|**.duplicate**()-> $class : cs.Document | Duplicates the current document and increments the name. The name of the new document will be ‘thisName (n).ext’ where n is the next number that yields a unique name in that location. |
|**.getJSON**()-> $object : Object | If the document is .json will parse the contents and return as an object. |
|**.get4Dfile()**-> $file : 4D.File | Returns the 4D.File root. |



### Picture functions

Along with the picture properties above these provide some useful actions for working with picture files.

|Function|Action|
|--------|------|
|**.getPicture**()-> $picture : Picture | Returns the content of the file as a picture. |



 ### Classic Document Functions

You can choose to work with the document using the classic commands. There are some good reasons for using these commands but in general the modern ones are better.

Be smart when you use these. It’s possible to combine the classic and modern functions. For instance - you can be writing to a file using `.send_packet()` and then use `$class.getText()` without having to close the document. However, attempting to use both `.send_packet()` _and_`.$class.setText()` is likely to have unpredicatable results.

|Function|Action|
|--------|------|
| **new_document**( $leaveOpen: Boolean) | Allows you to define the document using **Create document**. If $leaveOpen is true the document remains open in Read Write mode. Otherwise it’s closed. |
| **open_document**( $mode: Integer)-> $docRef: Time | Opens the document. If you haven’t defined the document it does nothing.<br />The docRef is returned. You can use it yourself or use the following commands. |
| **send_packet**( $content: Variant{; $append: Boolean {; $close: Boolean}}) | Sends the content to the document. $content is either `text` or `blob`. <br />$append if **False** by default.<br />$close is **False** by default.<br />See below for details. |
| **receive_packet_text**($delimiter: Variant) | Reads from the document. <br />The document must to open to read from it. <br />$delimiter can be a string of characters or an integer in which case it is the number of characters that will be read. <br />The starting point will begin at the end of the last read point. You can use `.set_document_postion()`. |
| **get_document_position**()->$positon : Integer | The position in the document the next read or write action will begin. |
| **set_document_position**($offset: Integer) | Sets the position in the document the next read or write action will begin. |
|  |  |

#### Send Packet

`.send_packet()` is more flexible than the classic command. If the document is not already open it will open it. So you can call `$class.send_packet($someText; True; True)` to open the document, append $someText and then close it again.

If you open the document before hand you can use `.set_document_position($x)` to insert the content.

Some Classic Code Examples
```4d
//  this simply defines the file
$class:=cs.Document.new(Folder(fk desktop folder).file("myClassyTest.txt"))

//  open it, write some text and close it again
$class.send_packet("This is line 1\n"; True; True)

//  this line will be appended...
$class.send_packet("This is line 2\n"; True; True)

```
