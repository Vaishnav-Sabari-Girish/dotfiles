use thiserror::Error;

use crate::api::data::{Error as DataError, OwnedData};
use crate::api::nonce::{request_nonce, NonceError};
use crate::api::request::{ensure_success, ResponseError};
use crate::api::url::UrlBuilder;
use crate::client::Client;
use crate::crypto::key_set::KeySet;
use crate::file::remote_file::RemoteFile;

/// An action to change a password of an uploaded Send file.
///
/// This API specification for this action is compatible with both Firefox Send v2 and v3.
pub struct Password<'a> {
    /// The remote file to change the password for.
    file: &'a RemoteFile,

    /// The new password to use for the file.
    password: &'a str,

    /// The authentication nonce.
    /// May be an empty vector if the nonce is unknown.
    nonce: Vec<u8>,
}

impl<'a> Password<'a> {
    /// Construct a new password action for the given remote file.
    pub fn new(file: &'a RemoteFile, password: &'a str, nonce: Option<Vec<u8>>) -> Self {
        Self {
            file,
            password,
            nonce: nonce.unwrap_or_default(),
        }
    }

    /// Invoke the password action.
    pub fn invoke(mut self, client: &Client) -> Result<(), Error> {
        // Create a key set for the file
        let mut key = KeySet::from(self.file, None);

        // Fetch the authentication nonce if not set yet
        if self.nonce.is_empty() {
            self.nonce = self.fetch_auth_nonce(client)?;
        }

        // Derive a new authentication key
        key.derive_auth_password(self.password, &UrlBuilder::download(self.file, true));

        // Build the password data, wrap it as owned
        let data = OwnedData::from(PasswordData::from(&key), &self.file)
            .map_err(|err| -> PrepareError { err.into() })?;

        // Send the request to change the password
        self.change_password(client, &data)
    }

    /// Fetch the authentication nonce for the file from the Send server.
    fn fetch_auth_nonce(&self, client: &Client) -> Result<Vec<u8>, Error> {
        request_nonce(client, UrlBuilder::download(self.file, false)).map_err(|err| err.into())
    }

    /// Send the request for changing the file password.
    fn change_password(
        &self,
        client: &Client,
        data: &OwnedData<PasswordData>,
    ) -> Result<(), Error> {
        // Get the password URL, and send the change
        let url = UrlBuilder::api_password(self.file);
        let response = client
            .post(url)
            .json(&data)
            .send()
            .map_err(|_| ChangeError::Request)?;

        // Ensure the response is successful
        ensure_success(&response).map_err(|err| err.into())
    }
}

/// The data object to send to the password endpoint,
/// which sets the file password.
#[derive(Debug, Serialize)]
struct PasswordData {
    /// The authentication key
    auth: String,
}

impl PasswordData {
    /// Create the password data object from the given key set.
    pub fn from(key: &KeySet) -> PasswordData {
        PasswordData {
            auth: key.auth_key_encoded().unwrap(),
        }
    }
}

#[derive(Error, Debug)]
pub enum Error {
    /// An error occurred while preparing the action.
    #[error("failed to prepare setting the password")]
    Prepare(#[from] PrepareError),

    /// The given Send file has expired, or did never exist in the first place.
    /// Therefore the file could not be downloaded.
    #[error("the file has expired or did never exist")]
    Expired,

    /// An error has occurred while sending the password change request to
    /// the server.
    #[error("failed to send the password change request")]
    Change(#[from] ChangeError),
}

impl From<NonceError> for Error {
    fn from(err: NonceError) -> Error {
        match err {
            NonceError::Expired => Error::Expired,
            err => Error::Prepare(PrepareError::Auth(err)),
        }
    }
}

impl From<ResponseError> for Error {
    fn from(err: ResponseError) -> Error {
        match err {
            ResponseError::Expired => Error::Expired,
            err => Error::Change(ChangeError::Response(err)),
        }
    }
}

#[derive(Error, Debug)]
pub enum PrepareError {
    /// Failed authenticating, needed to set a new password.
    #[error("failed to authenticate")]
    Auth(#[from] NonceError),

    /// Some error occurred while building the data that will be sent.
    /// The owner token might possibly be missing, the wrapped error will
    /// describe this further.
    #[error("")]
    Data(#[from] DataError),
}

#[derive(Error, Debug)]
pub enum ChangeError {
    /// Sending the request to change the password failed.
    #[error("failed to send password change request")]
    Request,

    /// The server responded with an error while changing the file password.
    #[error("bad response from server while changing password")]
    Response(#[from] ResponseError),
}
