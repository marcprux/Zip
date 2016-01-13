//
//  Zip.swift
//  Zip
//
//  Created by Roy Marmelstein on 13/12/2015.
//  Copyright © 2015 Roy Marmelstein. All rights reserved.
//

import Foundation
import minizip

public enum ZipError: ErrorType {
    case FileNotFound
    case UnzipError

    public var description: String {
        switch self {
        case .FileNotFound: return NSLocalizedString("File not found.", comment: "")
        case .UnzipError: return NSLocalizedString("Failed to unzip zip file.", comment: "")
        }
    }
}


public class Zip {
    
    public init () {}
    
    public func unzipFile(path: String, destination: String, overwrite: Bool) throws {
        // Check file exists at path.
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(path) == false {
            throw ZipError.FileNotFound
        }
        let zip = unzOpen(path)
        // Begin unzipping
        if unzGoToFirstFile(zip) != UNZ_OK {
            throw ZipError.UnzipError
        }
        var ret: Int32 = 0
        var crc_ret: Int32 = 0
        let bufferSize: UInt32 = 4096
        var buffer = Array<CUnsignedChar>(count: Int(bufferSize), repeatedValue: 0)
        repeat {
            ret = unzOpenCurrentFile(zip)
            if ret != UNZ_OK {
                throw ZipError.UnzipError
            }
            var fileInfo = unz_file_info()
            memset(&fileInfo, 0, sizeof(unz_file_info))
            ret = unzGetCurrentFileInfo(zip, &fileInfo, nil, 0, nil, 0, nil, 0)
            if ret != UNZ_OK {
                unzCloseCurrentFile(zip)
                throw ZipError.UnzipError
            }
            let fileNameSize = Int(fileInfo.size_filename) + 1
            let fileName = UnsafeMutablePointer<CChar>.alloc(fileNameSize)
            if fileName == nil {
                throw ZipError.UnzipError
            }
            unzGetCurrentFileInfo(zip, &fileInfo, fileName, UInt(fileNameSize), nil, 0, nil, 0)
            fileName[Int(fileInfo.size_filename)] = 0
            
            var strPath = String.fromCString(fileName)! as NSString
            var isDirectory = false
            let fileInfoSizeFileName = Int(fileInfo.size_filename-1)
            if (fileName[fileInfoSizeFileName] == "/".cStringUsingEncoding(NSUTF8StringEncoding)!.first! || fileName[fileInfoSizeFileName] == "\\".cStringUsingEncoding(NSUTF8StringEncoding)!.first!) {
                isDirectory = true;
            }
            free(fileName)
            
            if (strPath.rangeOfCharacterFromSet(NSCharacterSet(charactersInString: "/\\")).location != NSNotFound) {
                strPath = strPath.stringByReplacingOccurrencesOfString("\\", withString: "/")
            }
            let fullPath = (destination as NSString).stringByAppendingPathComponent(strPath as String)
            let creationDate = NSDate()
            let directoryAttributes = [NSFileCreationDate: creationDate, NSFileModificationDate: creationDate]
            if isDirectory {
                try fileManager.createDirectoryAtPath(fullPath, withIntermediateDirectories: true, attributes: directoryAttributes)
            }
            else {
                try fileManager.createDirectoryAtPath((fullPath as NSString).stringByDeletingLastPathComponent, withIntermediateDirectories: true, attributes: directoryAttributes)
            }
            
            if fileManager.fileExistsAtPath(fullPath) && !isDirectory && !overwrite {
                unzCloseCurrentFile(zip)
                ret = unzGoToNextFile(zip)
            }
            var filePointer: UnsafeMutablePointer<FILE>
            filePointer = fopen(fullPath, "wb")
            while filePointer != nil {
                let readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                if readBytes > 0 {
                    fwrite(buffer, Int(readBytes), 1, filePointer)
                }
                else {
                    break
                }
            }
            fclose(filePointer)
            crc_ret = unzCloseCurrentFile(zip)
            if crc_ret == UNZ_CRCERROR {
                throw ZipError.UnzipError
            }
            ret = unzGoToNextFile(zip)
        } while (ret == UNZ_OK && ret != UNZ_END_OF_LIST_OF_FILE)
    }

}