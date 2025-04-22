use serde::Serialize;
use thiserror::Error;

use crate::file::remote_file::RemoteFile;

/// An owned data structure, that wraps generic data.
/// This structure is used to send owned data to the Send server.
/// This owned data is authenticated using an `owner_token`,
/// which this structure manages.
#[derive(Debug, Serialize)]
pub struct OwnedData<D> {
    /// The owner token, used for request authentication purposes.
    owner_token: String,

    /// The wrapped data structure.
    #[serde(flatten)]
    inner: D,
}

impl<D> OwnedData<D>
where
    D: Serialize,
{
    /// Constructor.
    pub fn new(owner_token: String, inner: D) -> Self {
        OwnedData { owner_token, inner }
    }

    /// Wrap the given data structure with this owned data structure.
    /// A `file` must be given, having a set owner token.
    pub fn from(inner: D, file: &RemoteFile) -> Result<Self, Error> {
        Ok(Self::new(
            file.owner_token().ok_or(Error::NoOwnerToken)?.to_owned(),
            inner,
        ))
    }
}

#[derive(Debug, Error)]
pub enum Error {
    /// Missing owner token, which is required.
    #[error("missing owner token, must be specified")]
    NoOwnerToken,
}
