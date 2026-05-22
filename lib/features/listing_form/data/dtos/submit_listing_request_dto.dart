class SubmitListingRequestDto {
  const SubmitListingRequestDto({required this.listingId});

  final String listingId;

  Map<String, dynamic> toRpcParams() => <String, dynamic>{
    'p_listing_id': listingId,
  };
}
