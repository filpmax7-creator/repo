#import <UIKit/UIKit.h>
@interface FSLanguagePicker : UITableViewController
@property(nonatomic,copy) void (^chosen)(NSString *code);
@end
