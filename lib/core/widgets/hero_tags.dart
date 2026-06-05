/// Shared Hero tag scheme so the source (a listing card image) and the
/// destination (the listing-detail gallery's first page) compute the identical
/// tag. Keyed off the listing id — the only identifier guaranteed equal on both
/// ends (media ids/order can differ).
String listingImageHeroTag(String listingId) => 'listing-image-$listingId';
