use std::{fs, io, path::Path};

#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

// #[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
// pub struct FileId {
//     #[cfg(target_family = "unix")]
//     device: u64,

//     #[cfg(target_family = "unix")]
//     inode: u64,

//     #[cfg(target_family = "windows")]
//     volume_serial_number: u64,

//     #[cfg(target_family = "windows")]
//     file_id: u128,
// }

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct FileId {
    pub device: u64,
    pub inode: u64,
}

impl FileId {
    pub fn new(device: u64, inode: u64) -> Self {
        Self { device, inode }
    }
}

#[cfg(target_family = "unix")]
pub fn get_file_id(path: impl AsRef<Path>) -> io::Result<FileId> {
    use std::os::unix::fs::MetadataExt;

    let metadata = fs::metadata(path.as_ref())?;

    Ok(FileId {
        device: metadata.dev(),
        inode: metadata.ino(),
    })
}

#[cfg(target_family = "windows")]
pub fn get_file_id(path: impl AsRef<Path>) -> io::Result<FileId> {
    use winapi_util::{file::information, Handle};

    let handle = Handle::from_path_any(path.as_ref())?;
    let info = information(&handle)?;

    Ok(FileId {
        device: info.volume_serial_number(),
        inode: info.file_index(),
    })
}

// #[cfg(target_family = "windows")]
// pub fn get_file_id(path: impl AsRef<Path>) -> io::Result<FileId> {

//     use windows_sys::Win32::Foundation::HANDLE;
//     use windows_sys::Win32::Storage::FileSystem::GetFileInformationByHandleEx;
//     use windows_sys::Win32::Storage::FileSystem::FILE_INFO_BY_HANDLE_CLASS;
//     use windows_sys::Win32::Storage::FileSystem::FILE_ID_INFO;

//     let mut file_id_info: FILE_ID_INFO;

//     unsafe {
//         // https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfileinformationbyhandleex
//         GetFileInformationByHandleEx(
//             handle,
//             0x12,
//             *file_id_info,
//             std::mem::size_of(FILE_ID_INFO)
//         )

//     }

//     let handle = Handle::from_path_any(path.as_ref())?;
//     let info = information(&handle)?;

//     Ok(FileId {
//         file_index: info.file_index(),
//         volume_serial_number: info.volume_serial_number(),
//     })
// }
