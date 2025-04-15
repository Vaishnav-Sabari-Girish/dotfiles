use crate::{
	os::windows::{
		named_pipe::{
			enums::{PipeMode, PipeStreamRole},
			pipe_mode,
			tokio::{PipeStream, RawPipeStream},
			PipeListenerOptions, PipeModeTag,
		},
		winprelude::*,
	},
	Sealed,
};
use std::{
	fmt::{self, Debug, Formatter},
	io,
	marker::PhantomData,
	mem::replace,
};
use tokio::{net::windows::named_pipe::NamedPipeServer as TokioNPServer, sync::Mutex};

/// Tokio-based async server for a named pipe, asynchronously listening for connections to clients
/// and producing asynchronous pipe streams.
///
/// Note that this type does not correspond to any Tokio object, and is an invention of Interprocess
/// in its entirety.
///
/// The only way to create a `PipeListener` is to use [`PipeListenerOptions`]. See its documentation
/// for more.
///
/// # Examples
///
/// ## Basic server
/// ```no_run
#[doc = doctest_file::include_doctest!("examples/named_pipe/sync/stream/bytes.rs")]
/// ```
pub struct PipeListener<Rm: PipeModeTag, Sm: PipeModeTag> {
	config: PipeListenerOptions<'static>, // We need the options to create new instances
	stored_instance: Mutex<TokioNPServer>,
	_phantom: PhantomData<(Rm, Sm)>,
}
impl<Rm: PipeModeTag, Sm: PipeModeTag> PipeListener<Rm, Sm> {
	const STREAM_ROLE: PipeStreamRole = PipeStreamRole::get_for_rm_sm::<Rm, Sm>();

	/// Asynchronously waits until a client connects to the named pipe, creating a `Stream` to
	/// communicate with the pipe.
	pub async fn accept(&self) -> io::Result<PipeStream<Rm, Sm>> {
		let instance_to_hand_out = {
			let mut stored_instance = self.stored_instance.lock().await;
			stored_instance.connect().await?;
			let new_instance = self.create_instance()?;
			replace(&mut *stored_instance, new_instance)
		};

		let raw = RawPipeStream::new_server(instance_to_hand_out);
		Ok(PipeStream::new(raw))
	}

	/// Creates a listener from a [corresponding Tokio object](TokioNPServer) and a
	/// [`PipeListenerOptions`] table with the assumption that the handle was created with those
	/// options.
	///
	/// The options are necessary to provide because the listener needs to create new instances of
	/// the named pipe server in `.accept()`.
	// TODO(2.3.0) mention TryFrom<OwnedHandle> here
	pub fn from_tokio_and_options(
		tokio_object: TokioNPServer,
		options: PipeListenerOptions<'static>,
	) -> Self {
		Self {
			config: options,
			stored_instance: Mutex::new(tokio_object),
			_phantom: PhantomData,
		}
	}

	/// Creates a listener from a handle and a [`PipeListenerOptions`] table with the assumption
	/// that the handle was created with those options.
	///
	/// The options are necessary to provide because the listener needs to create new instances of
	/// the named pipe server in `.accept()`.
	///
	/// # Errors
	/// Returns an error if called outside a Tokio runtime.
	// TODO(2.3.0) mention TryFrom<OwnedHandle> here
	pub fn from_handle_and_options(
		handle: OwnedHandle,
		options: PipeListenerOptions<'static>,
	) -> io::Result<Self> {
		Ok(Self::from_tokio_and_options(
			npserver_from_handle(handle)?,
			options,
		))
	}

	fn create_instance(&self) -> io::Result<TokioNPServer> {
		self.config
			.create_instance(false, false, true, Self::STREAM_ROLE, Rm::MODE)
			.and_then(npserver_from_handle)
	}
}
impl<Rm: PipeModeTag, Sm: PipeModeTag> Debug for PipeListener<Rm, Sm> {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		f.debug_struct("PipeListener")
			.field("config", &self.config)
			.field("instance", &self.stored_instance)
			.finish()
	}
}

/// Extends [`PipeListenerOptions`] with a constructor method for the Tokio [`PipeListener`].
#[allow(private_bounds)]
pub trait PipeListenerOptionsExt: Sealed {
	/// Creates a Tokio pipe listener from the builder. See the
	/// [non-async `create` method on `PipeListenerOptions`](PipeListenerOptions::create) for more.
	///
	/// The `nonblocking` parameter is ignored and forced to be enabled.
	fn create_tokio<Rm: PipeModeTag, Sm: PipeModeTag>(&self) -> io::Result<PipeListener<Rm, Sm>>;
	/// Alias for [`.create_tokio()`](PipeListenerOptionsExt::create_tokio) with the same `Rm` and
	/// `Sm`.
	#[inline]
	fn create_tokio_duplex<M: PipeModeTag>(&self) -> io::Result<PipeListener<M, M>> {
		self.create_tokio::<M, M>()
	}
	/// Alias for [`.create_tokio()`](PipeListenerOptionsExt::create_tokio) with an `Sm` of
	/// [`pipe_mode::None`].
	#[inline]
	fn create_tokio_recv_only<Rm: PipeModeTag>(
		&self,
	) -> io::Result<PipeListener<Rm, pipe_mode::None>> {
		self.create_tokio::<Rm, pipe_mode::None>()
	}
	/// Alias for [`.create_tokio()`](PipeListenerOptionsExt::create_tokio) with an `Rm` of
	/// [`pipe_mode::None`].
	#[inline]
	fn create_tokio_send_only<Sm: PipeModeTag>(
		&self,
	) -> io::Result<PipeListener<pipe_mode::None, Sm>> {
		self.create_tokio::<pipe_mode::None, Sm>()
	}
}
impl PipeListenerOptionsExt for PipeListenerOptions<'_> {
	fn create_tokio<Rm: PipeModeTag, Sm: PipeModeTag>(&self) -> io::Result<PipeListener<Rm, Sm>> {
		let (owned_config, instance) =
			_create_tokio(self, PipeListener::<Rm, Sm>::STREAM_ROLE, Rm::MODE)?;
		Ok(PipeListener::from_tokio_and_options(instance, owned_config))
	}
}
impl Sealed for PipeListenerOptions<'_> {}
fn _create_tokio(
	config: &PipeListenerOptions<'_>,
	role: PipeStreamRole,
	recv_mode: Option<PipeMode>,
) -> io::Result<(PipeListenerOptions<'static>, TokioNPServer)> {
	// Shadow to avoid mixing them up.
	let mut config = config.to_owned()?;

	// Tokio should ideally already set that, but let's do it just in case.
	config.nonblocking = false;

	let instance = config
		.create_instance(true, false, true, role, recv_mode)
		.and_then(npserver_from_handle)?;

	Ok((config, instance))
}

fn npserver_from_handle(handle: OwnedHandle) -> io::Result<TokioNPServer> {
	unsafe { TokioNPServer::from_raw_handle(handle.into_raw_handle()) }
}
