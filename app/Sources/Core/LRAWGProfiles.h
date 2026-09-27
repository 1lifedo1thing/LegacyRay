/* amneziawg / wireguard profiles, as many as the user keeps, the way the
   amnezia client lists servers. each is a .conf file in awg/ under the app's
   preferences directory, which is where legacyray-kick accepts profiles from;
   display names live in a small plist beside them */
#import <Foundation/Foundation.h>

extern NSString * const LRAWGProfilesDidChangeNotification;

@interface LRAWGProfile : NSObject {
    NSString *_path;
    NSString *_name;
}
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *name;
- (NSString *)fileName;
- (NSString *)config;
/* "Endpoint = host:port" out of [Peer] */
- (NSString *)endpoint;
/* one line under the name: endpoint and whether it obfuscates */
- (NSString *)summary;
/* the [Interface] / [Peer] keys, lower-cased, first value wins */
- (NSDictionary *)fields;
/* YES when any amnezia obfuscation key is set; plain wireguard otherwise */
- (BOOL)isAmnezia;
@end

@interface LRAWGProfiles : NSObject
+ (NSString *)directory;
+ (NSArray *)profiles;                 /* LRAWGProfile, oldest first */
+ (LRAWGProfile *)profileAtPath:(NSString *)path;
+ (LRAWGProfile *)active;              /* the one POWER starts, or nil */
+ (void)setActive:(LRAWGProfile *)profile;
+ (BOOL)hasProfiles;

/* saves a new profile and asks the helper to validate it; on failure the file
   is removed again. done gets the profile, or nil and the reason */
+ (void)addConfig:(NSString *)text name:(NSString *)name
             done:(void (^)(LRAWGProfile *profile, NSString *error))done;
/* replace the text of an existing profile, validated the same way */
+ (void)updateProfile:(LRAWGProfile *)profile config:(NSString *)text
                 done:(void (^)(BOOL ok, NSString *error))done;
+ (void)renameProfile:(LRAWGProfile *)profile to:(NSString *)name;
+ (void)deleteProfile:(LRAWGProfile *)profile;

/* a name for a new profile from the endpoint, unique among the saved ones */
+ (NSString *)suggestedNameForConfig:(NSString *)text;
/* the pre-profiles single amneziawg.conf becomes the first profile */
+ (void)migrate;
@end
