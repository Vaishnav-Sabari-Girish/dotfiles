use core::hash::Hasher;

/// Since `TypeId`s are unique no need to hash them.  
/// This is the purpose of this hasher, not doing anything.  
/// It will get bytes, check if the number is right and return a `u64`.
#[derive(Default)]
pub(crate) struct TypeIdHasher(u64);

impl Hasher for TypeIdHasher {
    fn write(&mut self, bytes: &[u8]) {
        self.0 = u64::from_ne_bytes(bytes.try_into().unwrap());
    }
    fn finish(&self) -> u64 {
        self.0
    }
}

#[test]
fn hasher() {
    fn verify<T: 'static + ?Sized>() {
        use core::any::TypeId;
        use core::hash::Hash;

        let mut hasher = TypeIdHasher::default();
        let type_id = TypeId::of::<T>();
        type_id.hash(&mut hasher);
        assert_eq!(hasher.finish(), unsafe {
            core::mem::transmute::<TypeId, u64>(type_id)
        });
    }

    verify::<usize>();
    verify::<()>();
    verify::<str>();
    verify::<&'static str>();
    verify::<[u8; 20]>();
}
