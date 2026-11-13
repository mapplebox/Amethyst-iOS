#import "SceneDelegate.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

extern UIWindow *mainWindow;

@interface SceneDelegate ()

@end


static void importOpenedModpack(NSURL *url) {
    if (![url.pathExtension.lowercaseString isEqualToString:@"mrpack"]) return;
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [docs stringByAppendingPathComponent:@"modpacks"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *dest = [dir stringByAppendingPathComponent:url.lastPathComponent];
    [NSFileManager.defaultManager removeItemAtPath:dest error:nil];
    NSError *error;
    [NSFileManager.defaultManager copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:&error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (error) {
            showDialog(@"Import failed", error.localizedDescription);
        } else {
            showDialog(@"Modpack ready", [NSString stringWithFormat:@"%@ was saved. Open the modpack installer, tap Import .mrpack and pick it from the list.", url.lastPathComponent]);
        }
    });
}

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.frame = windowScene.coordinateSpace.bounds;
    mainWindow = self.window;
    launchInitialViewController(self.window);
    [self.window makeKeyAndVisible];
    for (UIOpenURLContext *ctx in connectionOptions.URLContexts) {
        importOpenedModpack(ctx.URL);
    }
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *ctx in URLContexts) {
        importOpenedModpack(ctx.URL);
    }
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
    CallbackBridge_pauseGameIfNeed();
}

@end
