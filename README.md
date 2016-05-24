# BiblioArchiver

An iOS webarchive tool written in Swift

## Feature

Archive web pages

## Usage

~~~swift
let url = NSURL(string: "https://onevcat.com/2016/01/create-framework/")!
Archiver.logEnabled = true
Archiver.archiveWebpageFormUrl(url) { (webarchiveData, error) in
guard let data = webarchiveData else {
    print("no data, error : \(error)")
    return
}
    
let webarchiveDirectory = FileHelper.webarchiveDirectory
let webarchivePath = "\(webarchiveDirectory)/\(FileHelper.testWebarchiveFile)"
if data.writeToFile(webarchivePath, atomically: true) {
    dispatch_async(dispatch_get_main_queue(), { 
        self.performSegueWithIdentifier("showWeb", sender: webarchivePath)
    })
}
else {
    print("failed to write file to disk")
}
~~~