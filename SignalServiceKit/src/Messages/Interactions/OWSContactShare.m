//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSContactShare.h"
#import "MimeTypeUtil.h"
#import "NSString+SSK.h"
#import "OWSSignalServiceProtos.pb.h"
#import "PhoneNumber.h"
#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import <YapDatabase/YapDatabaseTransaction.h>

@import Contacts;

NS_ASSUME_NONNULL_BEGIN

@interface OWSContactConversion ()

+ (nullable CNContact *)systemContactForContactName:(OWSContactName *)contactName;

@end

#pragma mark -

// NOTE: When changing the value of this feature flag, you also need
// to update the filtering in the SAE's info.plist.
BOOL kIsSendingContactSharesEnabled = YES;

NSString *NSStringForContactPhoneType(OWSContactPhoneType value)
{
    switch (value) {
        case OWSContactPhoneType_Home:
            return @"Home";
        case OWSContactPhoneType_Mobile:
            return @"Mobile";
        case OWSContactPhoneType_Work:
            return @"Work";
        case OWSContactPhoneType_Custom:
            return @"Custom";
    }
}

#pragma mark -

@implementation OWSContactPhoneNumber

- (BOOL)ows_isValid
{
    if (self.phoneNumber.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid phone number: %@.", self.logTag, self.phoneNumber);
        return NO;
    }
    return YES;
}

- (NSString *)localizedLabel
{
    switch (self.phoneType) {
        case OWSContactPhoneType_Home:
            return [CNLabeledValue localizedStringForLabel:CNLabelHome];
        case OWSContactPhoneType_Mobile:
            return [CNLabeledValue localizedStringForLabel:CNLabelPhoneNumberMobile];
        case OWSContactPhoneType_Work:
            return [CNLabeledValue localizedStringForLabel:CNLabelWork];
        default:
            if (self.label.ows_stripped.length < 1) {
                return NSLocalizedString(@"CONTACT_PHONE", @"Label for a contact's phone number.");
            }
            return self.label.ows_stripped;
    }
}

- (NSString *)logDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendFormat:@"[Phone Number: %@, ", NSStringForContactPhoneType(self.phoneType)];

    if (self.label.length > 0) {
        [result appendFormat:@"label: %@, ", self.label];
    }
    if (self.phoneNumber.length > 0) {
        [result appendFormat:@"phoneNumber: %@, ", self.phoneNumber];
    }

    [result appendString:@"]"];
    return result;
}

@end

#pragma mark -

NSString *NSStringForContactEmailType(OWSContactEmailType value)
{
    switch (value) {
        case OWSContactEmailType_Home:
            return @"Home";
        case OWSContactEmailType_Mobile:
            return @"Mobile";
        case OWSContactEmailType_Work:
            return @"Work";
        case OWSContactEmailType_Custom:
            return @"Custom";
    }
}

#pragma mark -

@implementation OWSContactEmail

- (BOOL)ows_isValid
{
    if (self.email.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid email: %@.", self.logTag, self.email);
        return NO;
    }
    return YES;
}

- (NSString *)localizedLabel
{
    switch (self.emailType) {
        case OWSContactEmailType_Home:
            return [CNLabeledValue localizedStringForLabel:CNLabelHome];
        case OWSContactEmailType_Mobile:
            return [CNLabeledValue localizedStringForLabel:CNLabelPhoneNumberMobile];
        case OWSContactEmailType_Work:
            return [CNLabeledValue localizedStringForLabel:CNLabelWork];
        default:
            if (self.label.ows_stripped.length < 1) {
                return NSLocalizedString(@"CONTACT_EMAIL", @"Label for a contact's email address.");
            }
            return self.label.ows_stripped;
    }
}

- (NSString *)logDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendFormat:@"[Email: %@, ", NSStringForContactEmailType(self.emailType)];

    if (self.label.length > 0) {
        [result appendFormat:@"label: %@, ", self.label];
    }
    if (self.email.length > 0) {
        [result appendFormat:@"email: %@, ", self.email];
    }

    [result appendString:@"]"];
    return result;
}

@end

#pragma mark -

NSString *NSStringForContactAddressType(OWSContactAddressType value)
{
    switch (value) {
        case OWSContactAddressType_Home:
            return @"Home";
        case OWSContactAddressType_Work:
            return @"Work";
        case OWSContactAddressType_Custom:
            return @"Custom";
    }
}

#pragma mark -

@implementation OWSContactAddress

- (BOOL)ows_isValid
{
    if (self.street.ows_stripped.length < 1 && self.pobox.ows_stripped.length < 1
        && self.neighborhood.ows_stripped.length < 1 && self.city.ows_stripped.length < 1
        && self.region.ows_stripped.length < 1 && self.postcode.ows_stripped.length < 1
        && self.country.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid address; empty.", self.logTag);
        return NO;
    }
    return YES;
}

- (NSString *)localizedLabel
{
    switch (self.addressType) {
        case OWSContactAddressType_Home:
            return [CNLabeledValue localizedStringForLabel:CNLabelHome];
        case OWSContactAddressType_Work:
            return [CNLabeledValue localizedStringForLabel:CNLabelWork];
        default:
            if (self.label.ows_stripped.length < 1) {
                return NSLocalizedString(@"CONTACT_ADDRESS", @"Label for a contact's postal address.");
            }
            return self.label.ows_stripped;
    }
}

- (NSString *)logDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendFormat:@"[Address: %@, ", NSStringForContactAddressType(self.addressType)];

    if (self.label.length > 0) {
        [result appendFormat:@"label: %@, ", self.label];
    }
    if (self.street.length > 0) {
        [result appendFormat:@"street: %@, ", self.street];
    }
    if (self.pobox.length > 0) {
        [result appendFormat:@"pobox: %@, ", self.pobox];
    }
    if (self.neighborhood.length > 0) {
        [result appendFormat:@"neighborhood: %@, ", self.neighborhood];
    }
    if (self.city.length > 0) {
        [result appendFormat:@"city: %@, ", self.city];
    }
    if (self.region.length > 0) {
        [result appendFormat:@"region: %@, ", self.region];
    }
    if (self.postcode.length > 0) {
        [result appendFormat:@"postcode: %@, ", self.postcode];
    }
    if (self.country.length > 0) {
        [result appendFormat:@"country: %@, ", self.country];
    }

    [result appendString:@"]"];
    return result;
}

@end

#pragma mark -

@implementation OWSContactName

- (NSString *)logDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendString:@"["];

    if (self.givenName.length > 0) {
        [result appendFormat:@"givenName: %@, ", self.givenName];
    }
    if (self.familyName.length > 0) {
        [result appendFormat:@"familyName: %@, ", self.familyName];
    }
    if (self.middleName.length > 0) {
        [result appendFormat:@"middleName: %@, ", self.middleName];
    }
    if (self.namePrefix.length > 0) {
        [result appendFormat:@"namePrefix: %@, ", self.namePrefix];
    }
    if (self.nameSuffix.length > 0) {
        [result appendFormat:@"nameSuffix: %@, ", self.nameSuffix];
    }
    if (self.displayName.length > 0) {
        [result appendFormat:@"displayName: %@, ", self.displayName];
    }

    [result appendString:@"]"];
    return result;
}

- (NSString *)displayName
{
    [self ensureDisplayName];

    if (_displayName.length < 1) {
        OWSProdLogAndFail(@"%@ could not derive a valid display name.", self.logTag);
        return NSLocalizedString(@"CONTACT_WITHOUT_NAME", @"Indicates that a contact has no name.");
    }
    return _displayName;
}

- (void)ensureDisplayName
{
    if (_displayName.length < 1) {
        CNContact *_Nullable systemContact = [OWSContactConversion systemContactForContactName:self];
        _displayName = [CNContactFormatter stringFromContact:systemContact style:CNContactFormatterStyleFullName];
    }
    if (_displayName.length < 1) {
        // Fall back to using the organization name.
        _displayName = self.organizationName;
    }
}

- (void)updateDisplayName
{
    _displayName = nil;

    [self ensureDisplayName];
}

+ (OWSContactName *)emptyName
{
    return [OWSContactName new];
}

@end

#pragma mark -

@interface OWSContactShareBase ()

@property (nonatomic, nullable) NSArray<NSString *> *e164PhoneNumbersCached;

@end

#pragma mark -

@implementation OWSContactShareBase

- (instancetype)init
{
    if (self = [super init]) {
        _name = [OWSContactName new];
        _phoneNumbers = @[];
        _emails = @[];
        _addresses = @[];
    }

    return self;
}

- (void)normalize
{
    self.phoneNumbers = [self.phoneNumbers
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OWSContactPhoneNumber *value,
                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return value.ows_isValid;
        }]];
    self.emails = [self.emails filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OWSContactEmail *value,
                                                               NSDictionary<NSString *, id> *_Nullable bindings) {
        return value.ows_isValid;
    }]];
    self.addresses =
        [self.addresses filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OWSContactAddress *value,
                                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return value.ows_isValid;
        }]];
}

- (BOOL)ows_isValid
{
    if (self.name.displayName.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid contact; no display name.", self.logTag);
        return NO;
    }
    BOOL hasValue = NO;
    for (OWSContactPhoneNumber *phoneNumber in self.phoneNumbers) {
        if (!phoneNumber.ows_isValid) {
            return NO;
        }
        hasValue = YES;
    }
    for (OWSContactEmail *email in self.emails) {
        if (!email.ows_isValid) {
            return NO;
        }
        hasValue = YES;
    }
    for (OWSContactAddress *address in self.addresses) {
        if (!address.ows_isValid) {
            return NO;
        }
        hasValue = YES;
    }
    return hasValue;
}

- (NSString *)logDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendString:@"["];

    [result appendFormat:@"%@, ", self.name.logDescription];

    for (OWSContactPhoneNumber *phoneNumber in self.phoneNumbers) {
        [result appendFormat:@"%@, ", phoneNumber.logDescription];
    }
    for (OWSContactEmail *email in self.emails) {
        [result appendFormat:@"%@, ", email.logDescription];
    }
    for (OWSContactAddress *address in self.addresses) {
        [result appendFormat:@"%@, ", address.logDescription];
    }

    [result appendString:@"]"];
    return result;
}

#pragma mark - Phone Numbers and Recipient IDs

- (NSArray<NSString *> *)systemContactsWithSignalAccountPhoneNumbers:(id<ContactsManagerProtocol>)contactsManager
{
    OWSAssert(contactsManager);

    return [self.e164PhoneNumbers
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *_Nullable recipientId,
                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return [contactsManager isSystemContactWithSignalAccount:recipientId];
        }]];
}

- (NSArray<NSString *> *)systemContactPhoneNumbers:(id<ContactsManagerProtocol>)contactsManager
{
    OWSAssert(contactsManager);

    return [self.e164PhoneNumbers
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *_Nullable recipientId,
                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return [contactsManager isSystemContact:recipientId];
        }]];
}

- (NSArray<NSString *> *)e164PhoneNumbers
{
    if (self.e164PhoneNumbersCached) {
        return self.e164PhoneNumbersCached;
    }
    NSMutableArray<NSString *> *e164PhoneNumbers = [NSMutableArray new];
    for (OWSContactPhoneNumber *phoneNumber in self.phoneNumbers) {
        PhoneNumber *_Nullable parsedPhoneNumber;
        parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromE164:phoneNumber.phoneNumber];
        if (!parsedPhoneNumber) {
            parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromUserSpecifiedText:phoneNumber.phoneNumber];
        }
        if (parsedPhoneNumber) {
            [e164PhoneNumbers addObject:parsedPhoneNumber.toE164];
        }
    }
    self.e164PhoneNumbersCached = e164PhoneNumbers;
    return e164PhoneNumbers;
}

@end

#pragma mark -

@implementation OWSContactShare

- (BOOL)hasAvatar
{
    return self.avatarAttachmentId != nil;
}

#pragma mark - Avatar

- (nullable TSAttachment *)avatarAttachmentWithTransaction:(YapDatabaseReadTransaction *)transaction
{
    return [TSAttachment fetchObjectWithUniqueID:self.avatarAttachmentId transaction:transaction];
}

- (void)saveAvatarData:(NSData *)rawAvatarData transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    OWSAssert(rawAvatarData);
    OWSAssert(transaction);

    // Always convert avatar to ensure that it is JPEG.
    //
    // TODO: Consider scaling large avatars.
    // TODO: Consider skipping conversion if already JPEG.
    UIImage *_Nullable avatarImage = [UIImage imageWithData:rawAvatarData];
    if (!avatarImage) {
        OWSFail(@"%@ could not load avatar data.", self.logTag);
        return;
    }
    [self saveAvatarImage:avatarImage transaction:transaction];
}

- (void)saveAvatarImage:(UIImage *)image transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    NSData *imageData = UIImageJPEGRepresentation(image, (CGFloat)0.9);

    TSAttachmentStream *attachmentStream = [[TSAttachmentStream alloc] initWithContentType:OWSMimeTypeImageJpeg
                                                                                 byteCount:(UInt32)imageData.length
                                                                            sourceFilename:nil];

    NSError *error;
    BOOL success = [attachmentStream writeData:imageData error:&error];
    OWSAssert(success && !error);

    [attachmentStream saveWithTransaction:transaction];
    self.avatarAttachmentId = attachmentStream.uniqueId;
}

- (void)setAvatarAttachmentId:(nullable NSString *)avatarAttachmentId
{
    _avatarAttachmentId = avatarAttachmentId;
}

@end

#pragma mark -

@implementation OWSContactShareProposed

- (BOOL)hasAvatar
{
    return self.avatarData != nil;
}

@end

#pragma mark -

@implementation OWSContactConversion

#pragma mark - VCard Serialization

+ (nullable CNContact *)systemContactForVCardData:(NSData *)data
{
    OWSAssert(data);

    NSError *error;
    NSArray<CNContact *> *_Nullable contacts = [CNContactVCardSerialization contactsWithData:data error:&error];
    if (!contacts || error) {
        OWSProdLogAndFail(@"%@ could not parse vcard: %@", self.logTag, error);
        return nil;
    }
    if (contacts.count < 1) {
        OWSProdLogAndFail(@"%@ empty vcard: %@", self.logTag, error);
        return nil;
    }
    if (contacts.count > 1) {
        OWSProdLogAndFail(@"%@ more than one contact in vcard: %@", self.logTag, error);
    }
    return contacts.firstObject;
}

+ (nullable NSData *)vCardDataForSystemContact:(CNContact *)systemContact
{
    OWSAssert(systemContact);

    NSError *error;
    NSData *_Nullable data = [CNContactVCardSerialization dataWithContacts:@[
        systemContact,
    ]
                                                                     error:&error];
    if (!data || error) {
        OWSProdLogAndFail(@"%@ could not serialize to vcard: %@", self.logTag, error);
        return nil;
    }
    if (data.length < 1) {
        OWSProdLogAndFail(@"%@ empty vcard data: %@", self.logTag, error);
        return nil;
    }
    return data;
}

#pragma mark - System Contact Conversion

+ (nullable OWSContactShareProposed *)contactShareForSystemContact:(CNContact *)systemContact
{
    if (!systemContact) {
        OWSProdLogAndFail(@"%@ Missing contact.", self.logTag);
        return nil;
    }

    OWSContactShareProposed *contact = [OWSContactShareProposed new];

    OWSContactName *contactName = [OWSContactName new];
    contactName.givenName = systemContact.givenName.ows_stripped;
    contactName.middleName = systemContact.middleName.ows_stripped;
    contactName.familyName = systemContact.familyName.ows_stripped;
    contactName.namePrefix = systemContact.namePrefix.ows_stripped;
    contactName.nameSuffix = systemContact.nameSuffix.ows_stripped;
    contactName.organizationName = systemContact.organizationName.ows_stripped;
    [contactName ensureDisplayName];
    contact.name = contactName;

    NSMutableArray<OWSContactPhoneNumber *> *phoneNumbers = [NSMutableArray new];
    for (CNLabeledValue<CNPhoneNumber *> *phoneNumberField in systemContact.phoneNumbers) {
        OWSContactPhoneNumber *phoneNumber = [OWSContactPhoneNumber new];

        // Make a best effort to parse the phone number to e164.
        NSString *unparsedPhoneNumber = phoneNumberField.value.stringValue;
        PhoneNumber *_Nullable parsedPhoneNumber;
        parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromE164:unparsedPhoneNumber];
        if (!parsedPhoneNumber) {
            parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromUserSpecifiedText:unparsedPhoneNumber];
        }
        if (parsedPhoneNumber) {
            phoneNumber.phoneNumber = parsedPhoneNumber.toE164;
        } else {
            phoneNumber.phoneNumber = unparsedPhoneNumber;
        }

        if ([phoneNumberField.label isEqualToString:CNLabelHome]) {
            phoneNumber.phoneType = OWSContactPhoneType_Home;
        } else if ([phoneNumberField.label isEqualToString:CNLabelWork]) {
            phoneNumber.phoneType = OWSContactPhoneType_Work;
        } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberMobile]) {
            phoneNumber.phoneType = OWSContactPhoneType_Mobile;
        } else {
            phoneNumber.phoneType = OWSContactPhoneType_Custom;
            phoneNumber.label = phoneNumberField.label;
        }
        [phoneNumbers addObject:phoneNumber];
    }
    contact.phoneNumbers = phoneNumbers;

    NSMutableArray<OWSContactEmail *> *emails = [NSMutableArray new];
    for (CNLabeledValue *emailField in systemContact.emailAddresses) {
        OWSContactEmail *email = [OWSContactEmail new];
        email.email = emailField.value;
        if ([emailField.label isEqualToString:CNLabelHome]) {
            email.emailType = OWSContactEmailType_Home;
        } else if ([emailField.label isEqualToString:CNLabelWork]) {
            email.emailType = OWSContactEmailType_Work;
        } else {
            email.emailType = OWSContactEmailType_Custom;
            email.label = emailField.label;
        }
        [emails addObject:email];
    }
    contact.emails = emails;

    NSMutableArray<OWSContactAddress *> *addresses = [NSMutableArray new];
    for (CNLabeledValue<CNPostalAddress *> *addressField in systemContact.postalAddresses) {
        OWSContactAddress *address = [OWSContactAddress new];
        address.street = addressField.value.street;
        // TODO: Is this the correct mapping?
        //        address.neighborhood = addressField.value.subLocality;
        address.city = addressField.value.city;
        // TODO: Is this the correct mapping?
        //        address.region = addressField.value.subAdministrativeArea;
        address.region = addressField.value.state;
        address.postcode = addressField.value.postalCode;
        // TODO: Should we be using 2-letter codes, 3-letter codes or names?
        address.country = addressField.value.ISOCountryCode;

        if ([addressField.label isEqualToString:CNLabelHome]) {
            address.addressType = OWSContactAddressType_Home;
        } else if ([addressField.label isEqualToString:CNLabelWork]) {
            address.addressType = OWSContactAddressType_Work;
        } else {
            address.addressType = OWSContactAddressType_Custom;
            address.label = addressField.label;
        }
        [addresses addObject:address];
    }
    contact.addresses = addresses;

    // Avatar
    contact.avatarData = [self avatarDataForSystemContact:systemContact];

    return contact;
}

+ (nullable NSData *)avatarDataForSystemContact:(CNContact *)systemContact
{
    if (!systemContact) {
        OWSProdLogAndFail(@"%@ Missing contact.", self.logTag);
        return nil;
    }

    // Avatar
    NSData *_Nullable imageData = systemContact.thumbnailImageData;
    if (!imageData) {
        imageData = systemContact.imageData;
    }
    return imageData;
}

+ (nullable CNContact *)systemContactForContactName:(OWSContactName *)contactName
{
    if (!contactName) {
        OWSProdLogAndFail(@"%@ Missing contact name.", self.logTag);
        return nil;
    }

    CNMutableContact *systemContact = [CNMutableContact new];
    systemContact.givenName = contactName.givenName;
    systemContact.middleName = contactName.middleName;
    systemContact.familyName = contactName.familyName;
    systemContact.namePrefix = contactName.namePrefix;
    systemContact.nameSuffix = contactName.nameSuffix;
    // We don't need to set display name, it's implicit for system contacts.
    systemContact.organizationName = contactName.organizationName;

    return systemContact;
}

+ (nullable CNContact *)systemContactForContactShare:(OWSContactShare *)contact
                                         transaction:(YapDatabaseReadTransaction *)transaction
{
    OWSAssert(transaction);

    if (!contact) {
        OWSProdLogAndFail(@"%@ Missing contact.", self.logTag);
        return nil;
    }

    CNMutableContact *systemContact = [CNMutableContact new];
    systemContact.givenName = contact.name.givenName;
    systemContact.middleName = contact.name.middleName;
    systemContact.familyName = contact.name.familyName;
    systemContact.namePrefix = contact.name.namePrefix;
    systemContact.nameSuffix = contact.name.nameSuffix;
    // We don't need to set display name, it's implicit for system contacts.
    systemContact.organizationName = contact.name.organizationName;

    NSMutableArray<CNLabeledValue<CNPhoneNumber *> *> *systemPhoneNumbers = [NSMutableArray new];
    for (OWSContactPhoneNumber *phoneNumber in contact.phoneNumbers) {
        switch (phoneNumber.phoneType) {
            case OWSContactPhoneType_Home:
                [systemPhoneNumbers
                    addObject:[CNLabeledValue
                                  labeledValueWithLabel:CNLabelHome
                                                  value:[CNPhoneNumber
                                                            phoneNumberWithStringValue:phoneNumber.phoneNumber]]];
                break;
            case OWSContactPhoneType_Mobile:
                [systemPhoneNumbers
                    addObject:[CNLabeledValue
                                  labeledValueWithLabel:CNLabelPhoneNumberMobile
                                                  value:[CNPhoneNumber
                                                            phoneNumberWithStringValue:phoneNumber.phoneNumber]]];
                break;
            case OWSContactPhoneType_Work:
                [systemPhoneNumbers
                    addObject:[CNLabeledValue
                                  labeledValueWithLabel:CNLabelWork
                                                  value:[CNPhoneNumber
                                                            phoneNumberWithStringValue:phoneNumber.phoneNumber]]];
                break;
            case OWSContactPhoneType_Custom:
                [systemPhoneNumbers
                    addObject:[CNLabeledValue
                                  labeledValueWithLabel:phoneNumber.label
                                                  value:[CNPhoneNumber
                                                            phoneNumberWithStringValue:phoneNumber.phoneNumber]]];
                break;
        }
    }
    systemContact.phoneNumbers = systemPhoneNumbers;

    NSMutableArray<CNLabeledValue<NSString *> *> *systemEmails = [NSMutableArray new];
    for (OWSContactEmail *email in contact.emails) {
        switch (email.emailType) {
            case OWSContactEmailType_Home:
                [systemEmails addObject:[CNLabeledValue labeledValueWithLabel:CNLabelHome value:email.email]];
                break;
            case OWSContactEmailType_Mobile:
                [systemEmails addObject:[CNLabeledValue labeledValueWithLabel:@"Mobile" value:email.email]];
                break;
            case OWSContactEmailType_Work:
                [systemEmails addObject:[CNLabeledValue labeledValueWithLabel:CNLabelWork value:email.email]];
                break;
            case OWSContactEmailType_Custom:
                [systemEmails addObject:[CNLabeledValue labeledValueWithLabel:email.label value:email.email]];
                break;
        }
    }
    systemContact.emailAddresses = systemEmails;

    NSMutableArray<CNLabeledValue<CNPostalAddress *> *> *systemAddresses = [NSMutableArray new];
    for (OWSContactAddress *address in contact.addresses) {
        CNMutablePostalAddress *systemAddress = [CNMutablePostalAddress new];
        systemAddress.street = address.street;
        // TODO: Is this the correct mapping?
        //        systemAddress.subLocality = address.neighborhood;
        systemAddress.city = address.city;
        // TODO: Is this the correct mapping?
        //        systemAddress.subAdministrativeArea = address.region;
        systemAddress.state = address.region;
        systemAddress.postalCode = address.postcode;
        // TODO: Should we be using 2-letter codes, 3-letter codes or names?
        systemAddress.ISOCountryCode = address.country;

        switch (address.addressType) {
            case OWSContactAddressType_Home:
                [systemAddresses addObject:[CNLabeledValue labeledValueWithLabel:CNLabelHome value:systemAddress]];
                break;
            case OWSContactAddressType_Work:
                [systemAddresses addObject:[CNLabeledValue labeledValueWithLabel:CNLabelWork value:systemAddress]];
                break;
            case OWSContactAddressType_Custom:
                [systemAddresses addObject:[CNLabeledValue labeledValueWithLabel:address.label value:systemAddress]];
                break;
        }
    }
    systemContact.postalAddresses = systemAddresses;

    // Avatar
    //
    // NOTE: We don't want to write profile avatars to system contacts.
    if (!contact.isProfileAvatar) {
        TSAttachment *_Nullable avatarAttachment = [contact avatarAttachmentWithTransaction:transaction];
        if ([avatarAttachment isKindOfClass:[TSAttachmentStream class]]) {
            TSAttachmentStream *avatarAttachmentStream = (TSAttachmentStream *)avatarAttachment;
            NSError *error;
            NSData *_Nullable avatarData = [avatarAttachmentStream readDataFromFileWithError:&error];
            if (error || !avatarData) {
                OWSProdLogAndFail(@"%@ could not read avatar data: %@", self.logTag, error);
            } else {
                systemContact.imageData = avatarData;
            }
        }
    }

    return systemContact;
}

#pragma mark -

+ (nullable OWSContactShareProposed *)contactShareForVCardData:(NSData *)data
{
    OWSAssert(data);

    CNContact *_Nullable systemContact = [self systemContactForVCardData:data];
    if (!systemContact) {
        return nil;
    }
    return [self contactShareForSystemContact:systemContact];
}

+ (nullable NSData *)vCardDataForContactShare:(OWSContactShare *)contact
                                  transaction:(YapDatabaseReadTransaction *)transaction
{
    OWSAssert(contact);
    OWSAssert(transaction);

    CNContact *_Nullable systemContact = [self systemContactForContactShare:contact transaction:transaction];
    if (!systemContact) {
        return nil;
    }
    return [self vCardDataForSystemContact:systemContact];
}

#pragma mark - Proto Serialization

+ (nullable OWSSignalServiceProtosDataMessageContact *)protoForContactShare:(OWSContactShare *)contact
{
    OWSAssert(contact);

    OWSSignalServiceProtosDataMessageContactBuilder *contactBuilder =
        [OWSSignalServiceProtosDataMessageContactBuilder new];

    OWSSignalServiceProtosDataMessageContactNameBuilder *nameBuilder =
        [OWSSignalServiceProtosDataMessageContactNameBuilder new];

    OWSContactName *contactName = contact.name;
    if (contactName.givenName.ows_stripped.length > 0) {
        nameBuilder.givenName = contactName.givenName.ows_stripped;
    }
    if (contactName.familyName.ows_stripped.length > 0) {
        nameBuilder.familyName = contactName.familyName.ows_stripped;
    }
    if (contactName.middleName.ows_stripped.length > 0) {
        nameBuilder.middleName = contactName.middleName.ows_stripped;
    }
    if (contactName.namePrefix.ows_stripped.length > 0) {
        nameBuilder.prefix = contactName.namePrefix.ows_stripped;
    }
    if (contactName.nameSuffix.ows_stripped.length > 0) {
        nameBuilder.suffix = contactName.nameSuffix.ows_stripped;
    }
    if (contactName.organizationName.ows_stripped.length > 0) {
        contactBuilder.organization = contactName.organizationName.ows_stripped;
    }
    nameBuilder.displayName = contactName.displayName;
    [contactBuilder setNameBuilder:nameBuilder];

    for (OWSContactPhoneNumber *phoneNumber in contact.phoneNumbers) {
        OWSSignalServiceProtosDataMessageContactPhoneBuilder *phoneBuilder =
            [OWSSignalServiceProtosDataMessageContactPhoneBuilder new];
        phoneBuilder.value = phoneNumber.phoneNumber;
        if (phoneNumber.label.ows_stripped.length > 0) {
            phoneBuilder.label = phoneNumber.label.ows_stripped;
        }
        switch (phoneNumber.phoneType) {
            case OWSContactPhoneType_Home:
                phoneBuilder.type = OWSSignalServiceProtosDataMessageContactPhoneTypeHome;
                break;
            case OWSContactPhoneType_Mobile:
                phoneBuilder.type = OWSSignalServiceProtosDataMessageContactPhoneTypeMobile;
                break;
            case OWSContactPhoneType_Work:
                phoneBuilder.type = OWSSignalServiceProtosDataMessageContactPhoneTypeWork;
                break;
            case OWSContactPhoneType_Custom:
                phoneBuilder.type = OWSSignalServiceProtosDataMessageContactPhoneTypeCustom;
                break;
        }
        [contactBuilder addNumber:phoneBuilder.build];
    }

    for (OWSContactEmail *email in contact.emails) {
        OWSSignalServiceProtosDataMessageContactEmailBuilder *emailBuilder =
            [OWSSignalServiceProtosDataMessageContactEmailBuilder new];
        emailBuilder.value = email.email;
        if (email.label.ows_stripped.length > 0) {
            emailBuilder.label = email.label.ows_stripped;
        }
        switch (email.emailType) {
            case OWSContactEmailType_Home:
                emailBuilder.type = OWSSignalServiceProtosDataMessageContactEmailTypeHome;
                break;
            case OWSContactEmailType_Mobile:
                emailBuilder.type = OWSSignalServiceProtosDataMessageContactEmailTypeMobile;
                break;
            case OWSContactEmailType_Work:
                emailBuilder.type = OWSSignalServiceProtosDataMessageContactEmailTypeWork;
                break;
            case OWSContactEmailType_Custom:
                emailBuilder.type = OWSSignalServiceProtosDataMessageContactEmailTypeCustom;
                break;
        }
        [contactBuilder addEmail:emailBuilder.build];
    }

    for (OWSContactAddress *address in contact.addresses) {
        OWSSignalServiceProtosDataMessageContactPostalAddressBuilder *addressBuilder =
            [OWSSignalServiceProtosDataMessageContactPostalAddressBuilder new];
        if (address.label.ows_stripped.length > 0) {
            addressBuilder.label = address.label.ows_stripped;
        }
        if (address.street.ows_stripped.length > 0) {
            addressBuilder.street = address.street.ows_stripped;
        }
        if (address.pobox.ows_stripped.length > 0) {
            addressBuilder.pobox = address.pobox.ows_stripped;
        }
        if (address.neighborhood.ows_stripped.length > 0) {
            addressBuilder.neighborhood = address.neighborhood.ows_stripped;
        }
        if (address.city.ows_stripped.length > 0) {
            addressBuilder.city = address.city.ows_stripped;
        }
        if (address.region.ows_stripped.length > 0) {
            addressBuilder.region = address.region.ows_stripped;
        }
        if (address.postcode.ows_stripped.length > 0) {
            addressBuilder.postcode = address.postcode.ows_stripped;
        }
        if (address.country.ows_stripped.length > 0) {
            addressBuilder.country = address.country.ows_stripped;
        }
        [contactBuilder addAddress:addressBuilder.build];
    }

    if (contact.avatarAttachmentId != nil) {
        OWSSignalServiceProtosDataMessageContactAvatarBuilder *avatarBuilder =
            [OWSSignalServiceProtosDataMessageContactAvatarBuilder new];
        avatarBuilder.avatar = [TSAttachmentStream buildProtoForAttachmentId:contact.avatarAttachmentId];
        contactBuilder.avatar = [avatarBuilder build];
    }

    OWSSignalServiceProtosDataMessageContact *contactProto = [contactBuilder build];
    if (contactProto.number.count < 1 && contactProto.email.count < 1 && contactProto.address.count < 1) {
        OWSProdLogAndFail(@"%@ contact has neither phone, email or address.", self.logTag);
        return nil;
    }
    return contactProto;
}

+ (nullable OWSContactShare *)contactShareForDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                                   relay:(nullable NSString *)relay
                                             transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    OWSAssert(dataMessage);

    if (dataMessage.contact.count < 1) {
        return nil;
    }
    OWSAssert(dataMessage.contact.count == 1);
    OWSSignalServiceProtosDataMessageContact *contactProto = dataMessage.contact.firstObject;

    OWSContactShare *contact = [OWSContactShare new];

    OWSContactName *contactName = [OWSContactName new];
    if (contactProto.hasName) {
        OWSSignalServiceProtosDataMessageContactName *nameProto = contactProto.name;

        if (nameProto.hasGivenName) {
            contactName.givenName = nameProto.givenName.ows_stripped;
        }
        if (nameProto.hasFamilyName) {
            contactName.familyName = nameProto.familyName.ows_stripped;
        }
        if (nameProto.hasPrefix) {
            contactName.namePrefix = nameProto.prefix.ows_stripped;
        }
        if (nameProto.hasSuffix) {
            contactName.nameSuffix = nameProto.suffix.ows_stripped;
        }
        if (nameProto.hasMiddleName) {
            contactName.middleName = nameProto.middleName.ows_stripped;
        }
        if (nameProto.hasDisplayName) {
            contactName.displayName = nameProto.displayName.ows_stripped;
        }
    }
    if (contactProto.hasOrganization) {
        contactName.organizationName = contactProto.organization.ows_stripped;
    }
    [contactName ensureDisplayName];
    contact.name = contactName;

    NSMutableArray<OWSContactPhoneNumber *> *phoneNumbers = [NSMutableArray new];
    for (OWSSignalServiceProtosDataMessageContactPhone *phoneNumberProto in contactProto.number) {
        OWSContactPhoneNumber *_Nullable phoneNumber = [self phoneNumberForProto:phoneNumberProto];
        if (phoneNumber) {
            [phoneNumbers addObject:phoneNumber];
        }
    }
    contact.phoneNumbers = [phoneNumbers copy];

    NSMutableArray<OWSContactEmail *> *emails = [NSMutableArray new];
    for (OWSSignalServiceProtosDataMessageContactEmail *emailProto in contactProto.email) {
        OWSContactEmail *_Nullable email = [self emailForProto:emailProto];
        if (email) {
            [emails addObject:email];
        }
    }
    contact.emails = [emails copy];

    NSMutableArray<OWSContactAddress *> *addresses = [NSMutableArray new];
    for (OWSSignalServiceProtosDataMessageContactPostalAddress *addressProto in contactProto.address) {
        OWSContactAddress *_Nullable address = [self addressForProto:addressProto];
        if (address) {
            [addresses addObject:address];
        }
    }
    contact.addresses = [addresses copy];

    if (contactProto.hasAvatar) {
        OWSSignalServiceProtosDataMessageContactAvatar *avatarInfo = contactProto.avatar;

        if (avatarInfo.hasAvatar) {
            OWSSignalServiceProtosAttachmentPointer *avatarAttachment = avatarInfo.avatar;

            TSAttachmentPointer *attachmentPointer =
                [TSAttachmentPointer attachmentPointerFromProto:avatarAttachment relay:relay];
            [attachmentPointer saveWithTransaction:transaction];

            contact.avatarAttachmentId = attachmentPointer.uniqueId;
            contact.isProfileAvatar = avatarInfo.isProfile;
        } else {
            OWSFail(@"%@ in %s avatarInfo.hasAvatar was unexpectedly false", self.logTag, __PRETTY_FUNCTION__);
        }
    }

    return contact;
}

+ (nullable OWSContactPhoneNumber *)phoneNumberForProto:
    (OWSSignalServiceProtosDataMessageContactPhone *)phoneNumberProto
{
    OWSContactPhoneNumber *result = [OWSContactPhoneNumber new];
    result.phoneType = OWSContactPhoneType_Custom;
    if (phoneNumberProto.hasType) {
        switch (phoneNumberProto.type) {
            case OWSSignalServiceProtosDataMessageContactPhoneTypeHome:
                result.phoneType = OWSContactPhoneType_Home;
                break;
            case OWSSignalServiceProtosDataMessageContactPhoneTypeMobile:
                result.phoneType = OWSContactPhoneType_Mobile;
                break;
            case OWSSignalServiceProtosDataMessageContactPhoneTypeWork:
                result.phoneType = OWSContactPhoneType_Work;
                break;
            default:
                break;
        }
    }
    if (phoneNumberProto.hasLabel) {
        result.label = phoneNumberProto.label.ows_stripped;
    }
    if (phoneNumberProto.hasValue) {
        result.phoneNumber = phoneNumberProto.value.ows_stripped;
    } else {
        return nil;
    }
    return result;
}

+ (nullable OWSContactEmail *)emailForProto:(OWSSignalServiceProtosDataMessageContactEmail *)emailProto
{
    OWSContactEmail *result = [OWSContactEmail new];
    result.emailType = OWSContactEmailType_Custom;
    if (emailProto.hasType) {
        switch (emailProto.type) {
            case OWSSignalServiceProtosDataMessageContactEmailTypeHome:
                result.emailType = OWSContactEmailType_Home;
                break;
            case OWSSignalServiceProtosDataMessageContactEmailTypeMobile:
                result.emailType = OWSContactEmailType_Mobile;
                break;
            case OWSSignalServiceProtosDataMessageContactEmailTypeWork:
                result.emailType = OWSContactEmailType_Work;
                break;
            default:
                break;
        }
    }
    if (emailProto.hasLabel) {
        result.label = emailProto.label.ows_stripped;
    }
    if (emailProto.hasValue) {
        result.email = emailProto.value.ows_stripped;
    } else {
        return nil;
    }
    return result;
}

+ (nullable OWSContactAddress *)addressForProto:(OWSSignalServiceProtosDataMessageContactPostalAddress *)addressProto
{
    OWSContactAddress *result = [OWSContactAddress new];
    result.addressType = OWSContactAddressType_Custom;
    if (addressProto.hasType) {
        switch (addressProto.type) {
            case OWSSignalServiceProtosDataMessageContactPostalAddressTypeHome:
                result.addressType = OWSContactAddressType_Home;
                break;
            case OWSSignalServiceProtosDataMessageContactPostalAddressTypeWork:
                result.addressType = OWSContactAddressType_Work;
                break;
            default:
                break;
        }
    }
    if (addressProto.hasLabel) {
        result.label = addressProto.label.ows_stripped;
    }
    if (addressProto.hasStreet) {
        result.street = addressProto.street.ows_stripped;
    }
    if (addressProto.hasPobox) {
        result.pobox = addressProto.pobox.ows_stripped;
    }
    if (addressProto.hasNeighborhood) {
        result.neighborhood = addressProto.neighborhood.ows_stripped;
    }
    if (addressProto.hasCity) {
        result.city = addressProto.city.ows_stripped;
    }
    if (addressProto.hasRegion) {
        result.region = addressProto.region.ows_stripped;
    }
    if (addressProto.hasPostcode) {
        result.postcode = addressProto.postcode.ows_stripped;
    }
    if (addressProto.hasCountry) {
        result.country = addressProto.country.ows_stripped;
    }
    return result;
}

@end

NS_ASSUME_NONNULL_END