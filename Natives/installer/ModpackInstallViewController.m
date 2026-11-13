#import "AFNetworking.h"
#import "LauncherNavigationController.h"
#import "ModpackInstallViewController.h"
#import "UIKit+AFNetworking.h"
#import "UIKit+hook.h"
#import "WFWorkflowProgressView.h"
#import "modpack/ModrinthAPI.h"
#import "config.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#include <dlfcn.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define kCurseForgeGameIDMinecraft 432
#define kCurseForgeClassIDModpack 4471
#define kCurseForgeClassIDMod 6

@interface ModpackInstallViewController()<UIContextMenuInteractionDelegate, UIDocumentPickerDelegate>
@property(nonatomic) UISearchController *searchController;
@property(nonatomic) UIMenu *currentMenu;
@property(nonatomic) NSMutableArray *list;
@property(nonatomic) NSMutableDictionary *filters;
@property ModrinthAPI *modrinth;
@end

static ModpackInstallViewController *gPickerOwner;

@implementation ModpackInstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    //NSString *curseforgeAPIKey = CONFIG_CURSEFORGE_API_KEY;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.modrinth = [ModrinthAPI new];
    self.filters = @{
        @"isModpack": @(YES),
        @"name": @" "
        // mcVersion
    }.mutableCopy;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Import .mrpack" style:UIBarButtonItemStylePlain target:self action:@selector(actionImportMrpack)];
    [self updateSearchResults];
}

- (NSArray<NSString *> *)localMrpackFiles {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSMutableArray *found = [NSMutableArray new];
    for (NSString *dir in @[docs, [docs stringByAppendingPathComponent:@"modpacks"]]) {
        for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil]) {
            if ([f.pathExtension.lowercaseString isEqualToString:@"mrpack"]) {
                [found addObject:[dir stringByAppendingPathComponent:f]];
            }
        }
    }
    return found;
}

- (void)importLocalMrpackAtPath:(NSString *)src {
    NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"import-" stringByAppendingString:src.lastPathComponent]];
    [NSFileManager.defaultManager removeItemAtPath:dest error:nil];
    NSError *error;
    [NSFileManager.defaultManager copyItemAtPath:src toPath:dest error:&error];
    if (error) {
        showDialog(localize(@"Error", nil), error.localizedDescription);
        return;
    }
    [NSFileManager.defaultManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"icon.png"] error:nil];
    NSLog(@"[ModpackImport] Installing local modpack %@", dest);
    [NSNotificationCenter.defaultCenter postNotificationName:@"InstallModpack" object:self.modrinth userInfo:@{@"localPath": dest}];
    UINavigationController *nav = self.navigationController;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [nav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)actionImportMrpack {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Import .mrpack"
        message:@"Files in On My iPhone > Amethyst are listed here." preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *path in [self localMrpackFiles]) {
        [sheet addAction:[UIAlertAction actionWithTitle:path.lastPathComponent style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self importLocalMrpackAtPath:path];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Choose from Files..." style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIViewController *root = self.navigationController.presentingViewController;
        gPickerOwner = self; // keep alive: the picker's delegate is weak and this sheet gets dismissed
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
                initForOpeningContentTypes:@[UTTypeItem] asCopy:YES];
            picker.delegate = gPickerOwner;
            picker.allowsMultipleSelection = NO;
            picker.modalPresentationStyle = UIModalPresentationFullScreen;
            [root presentViewController:picker animated:YES completion:nil];
        }];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    gPickerOwner = nil;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    dispatch_async(dispatch_get_main_queue(), ^{ gPickerOwner = nil; });
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSString *ext = url.pathExtension.lowercaseString;
    if (![ext isEqualToString:@"mrpack"] && ![ext isEqualToString:@"zip"]) {
        showDialog(localize(@"Error", nil), @"Please pick a Modrinth modpack file (.mrpack).");
        return;
    }
    NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"import-" stringByAppendingString:url.lastPathComponent]];
    [NSFileManager.defaultManager removeItemAtPath:dest error:nil];
    NSError *error;
    [NSFileManager.defaultManager copyItemAtPath:url.path toPath:dest error:&error];
    if (error) {
        showDialog(localize(@"Error", nil), error.localizedDescription);
        return;
    }
    // no Modrinth icon for local packs: drop a stale icon from an earlier install
    [NSFileManager.defaultManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"icon.png"] error:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:@"InstallModpack" object:self.modrinth userInfo:@{@"localPath": dest}];
}

- (void)loadSearchResultsWithPrevList:(BOOL)prevList {
    NSString *name = self.searchController.searchBar.text;
    if (!prevList && [self.filters[@"name"] isEqualToString:name]) {
        return;
    }

    [self switchToLoadingState];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.filters[@"name"] = name;
        self.list = [self.modrinth searchModWithFilters:self.filters previousPageResult:prevList ? self.list : nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.list) {
                [self switchToReadyState];
                [self.tableView reloadData];
            } else {
                showDialog(localize(@"Error", nil), self.modrinth.lastError.localizedDescription);
                [self actionClose];
            }
        });
    });
}

- (void)updateSearchResults {
    [self loadSearchResultsWithPrevList:NO];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateSearchResults) object:nil];
    [self performSelector:@selector(updateSearchResults) withObject:nil afterDelay:0.5];
}

- (void)actionClose {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchToLoadingState {
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:indicator];
    [indicator startAnimating];
    self.navigationController.modalInPresentation = YES;
    self.tableView.allowsSelection = NO;
}

- (void)switchToReadyState {
    UIActivityIndicatorView *indicator = (id)self.navigationItem.rightBarButtonItem.customView;
    [indicator stopAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(actionClose)];
    self.navigationController.modalInPresentation = NO;
    self.tableView.allowsSelection = YES;
}

#pragma mark UIContextMenu

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return self.currentMenu;
    }];
}

- (_UIContextMenuStyle *)_contextMenuInteraction:(UIContextMenuInteraction *)interaction styleForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    _UIContextMenuStyle *style = [_UIContextMenuStyle defaultStyle];
    style.preferredLayout = 3; // _UIContextMenuLayoutCompactMenu
    return style;
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.imageView.contentMode = UIViewContentModeScaleToFill;
        cell.imageView.clipsToBounds = YES;
    }

    NSDictionary *item = self.list[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"description"];
    UIImage *fallbackImage = [UIImage imageNamed:@"DefaultProfile"];
    [cell.imageView setImageWithURL:[NSURL URLWithString:item[@"imageUrl"]] placeholderImage:fallbackImage];

    if (!self.modrinth.reachedLastPage && indexPath.row == self.list.count-1) {
        [self loadSearchResultsWithPrevList:YES];
    }

    return cell;
}

- (void)showDetails:(NSDictionary *)details atIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];

    NSMutableArray<UIAction *> *menuItems = [[NSMutableArray alloc] init];
    [details[@"versionNames"] enumerateObjectsUsingBlock:
    ^(NSString *name, NSUInteger i, BOOL *stop) {
        NSString *nameWithVersion = name;
        NSString *mcVersion = details[@"mcVersionNames"][i];
        if (![name hasSuffix:mcVersion]) {
            nameWithVersion = [NSString stringWithFormat:@"%@ - %@", name, mcVersion];
        }
        [menuItems addObject:[UIAction
            actionWithTitle:nameWithVersion
            image:nil identifier:nil
            handler:^(UIAction *action) {
            [self actionClose];
            NSString *tmpIconPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"icon.png"];
                [UIImagePNGRepresentation([cell.imageView.image _imageWithSize:CGSizeMake(40, 40)]) writeToFile:tmpIconPath atomically:YES];
            [self.modrinth installModpackFromDetail:self.list[indexPath.row] atIndex:i];
        }]];
    }];

    self.currentMenu = [UIMenu menuWithTitle:@"" children:menuItems];
    UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    cell.detailTextLabel.interactions = @[interaction];
    [interaction _presentMenuAtLocation:CGPointZero];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.list[indexPath.row];
    if ([item[@"versionDetailsLoaded"] boolValue]) {
        [self showDetails:item atIndexPath:indexPath];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [self switchToLoadingState];
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.modrinth loadDetailsOfMod:self.list[indexPath.row]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self switchToReadyState];
            if ([item[@"versionDetailsLoaded"] boolValue]) {
                [self showDetails:item atIndexPath:indexPath];
            } else {
                showDialog(localize(@"Error", nil), self.modrinth.lastError.localizedDescription);
            }
        });
    });
}

@end
