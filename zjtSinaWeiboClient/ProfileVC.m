//
//  ProfileVC.m
//  zjtSinaWeiboClient
//
//  Created by jianting zhu on 12-2-25.
//  Copyright (c) 2012年 Dunbar Science & Technology. All rights reserved.
//

#import "ProfileVC.h"
#import "WeiBoMessageManager.h"
#import "Status.h"
#import "User.h"
#import "ASIHTTPRequest.h"
#import "HHNetDataCacheManager.h"
#import "ImageBrowser.h"
#import "GifView.h"
#import "SHKActivityIndicator.h"
#import "ZJTDetailStatusVC.h"

@interface ProfileVC ()

- (void)getImages;

@end

@implementation ProfileVC
@synthesize table;
@synthesize userID;
@synthesize statusCellNib;
@synthesize statuesArr;
@synthesize headDictionary;
@synthesize imageDictionary;
@synthesize browserView;
@synthesize headerView;
@synthesize headerVImageV;
@synthesize headerVNameLB;
@synthesize weiboCount;
@synthesize followerCount;
@synthesize followingCount;
@synthesize user;
@synthesize avatarImage;

-(void)dealloc
{
    self.avatarImage = nil;
    self.user = nil;
    self.headDictionary = nil;
    self.imageDictionary = nil;
    self.statusCellNib = nil;
    self.statuesArr = nil;
    self.userID = nil;
    self.browserView = nil;
    [table release];
    [headerView release];
    [headerVImageV release];
    [headerVNameLB release];
    [weiboCount release];
    [followerCount release];
    [followingCount release];
    [super dealloc];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
//        self.title = 
        
        //init data
        shouldLoad = NO;
        shouldLoadAvatar = NO;
        shouldShowIndicator = YES;
        manager = [WeiBoMessageManager getInstance];
        defaultNotifCenter = [NSNotificationCenter defaultCenter];
        headDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
        imageDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
    }
    return self;
}

-(UINib*)statusCellNib
{
    if (statusCellNib == nil) 
    {
        self.statusCellNib = [StatusCell nib];
    }
    return statusCellNib;
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    [table setTableHeaderView:headerView];
    
    if (avatarImage) {
        self.headerVImageV.image = avatarImage;
    }
    
    if (user) {
        self.headerVNameLB.text = user.screenName;
        self.weiboCount.text = [NSString stringWithFormat:@"%d",user.statusesCount];
        self.followerCount.text = [NSString stringWithFormat:@"%d",user.followersCount];
        self.followingCount.text = [NSString stringWithFormat:@"%d",user.friendsCount];
    }
    
    self.tableView.contentInset = UIEdgeInsetsOriginal;
    
    NSLog([manager isNeedToRefreshTheToken] == YES ? @"need to login":@"will login");
    
    [manager getUserStatusUserID:userID sinceID:-1 maxID:-1 count:-1 page:-1 baseApp:-1 feature:-1];
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    if (shouldLoad) 
    {
        shouldLoad = NO;
        [manager getUserStatusUserID:userID sinceID:-1 maxID:-1 count:-1 page:-1 baseApp:-1 feature:-1];
    }
    [defaultNotifCenter addObserver:self selector:@selector(didGetHomeLine:)    name:MMSinaGotUserStatus        object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(getAvatar:)         name:HHNetDataCacheNotification object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(didGetUserInfo:)    name:MMSinaGotUserInfo          object:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [defaultNotifCenter removeObserver:self name:MMSinaGotUserStatus        object:nil];
    [defaultNotifCenter removeObserver:self name:HHNetDataCacheNotification object:nil];
    [defaultNotifCenter removeObserver:self name:MMSinaGotUserInfo          object:nil];
    [super viewWillDisappear:animated];
}

- (void)viewDidUnload 
{
    [self setTable:nil];
    [self setHeaderView:nil];
    [self setHeaderVImageV:nil];
    [self setHeaderVNameLB:nil];
    [self setWeiboCount:nil];
    [self setFollowerCount:nil];
    [self setFollowingCount:nil];
    [super viewDidUnload];
}


#pragma mark - Methods

//异步加载图片
-(void)getImages
{
    //得到文字数据后，开始加载图片
    for(int i=0;i<[statuesArr count];i++)
    {
        Status * member=[statuesArr objectAtIndex:i];
        NSNumber *indexNumber = [NSNumber numberWithInt:i];
        
        //下载头像图片
        [[HHNetDataCacheManager getInstance] getDataWithURL:member.user.profileLargeImageUrl withIndex:i];
        
        //下载博文图片
        if (member.thumbnailPic && [member.thumbnailPic length] != 0)
        {
            [[HHNetDataCacheManager getInstance] getDataWithURL:member.thumbnailPic withIndex:i];
        }
        else
        {
            [imageDictionary setObject:[NSNull null] forKey:indexNumber];
        }
        
        //下载转发的图片
        if (member.retweetedStatus.thumbnailPic && [member.retweetedStatus.thumbnailPic length] != 0) 
        {
            [[HHNetDataCacheManager getInstance] getDataWithURL:member.retweetedStatus.thumbnailPic withIndex:i];
        }
        else
        {
            [imageDictionary setObject:[NSNull null] forKey:indexNumber];
        }
    }
}

//得到图片
-(void)getAvatar:(NSNotification*)sender
{
    NSDictionary * dic = sender.object;
    NSString * url          = [dic objectForKey:HHNetDataCacheURLKey];
    NSNumber *indexNumber   = [dic objectForKey:HHNetDataCacheIndex];
    NSInteger index = [indexNumber intValue];
    
    if (index > [statuesArr count]) {
        NSLog(@"statues arr error ,index = %d,count = %d",index,[statuesArr count]);
        return;
    }
    
    Status *sts = [statuesArr objectAtIndex:index];
    
    //得到的是头像图片
    if ([url isEqualToString:user.profileLargeImageUrl]) 
    {
        UIImage * image     = [UIImage imageWithData:[dic objectForKey:HHNetDataCacheData]];
        user.avatarImage    = image;
        self.headerVImageV.image = image;
        
        [headDictionary setObject:[dic objectForKey:HHNetDataCacheData] forKey:indexNumber];
    }
    
    //得到的是博文图片
    if([url isEqualToString:sts.thumbnailPic])
    {
        [imageDictionary setObject:[dic objectForKey:HHNetDataCacheData] forKey:indexNumber];
    }
    
    //得到的是转发的图片
    if (sts.retweetedStatus && ![sts.retweetedStatus isEqual:[NSNull null]])
    {
        if ([url isEqualToString:sts.retweetedStatus.thumbnailPic])
        {
            [imageDictionary setObject:[dic objectForKey:HHNetDataCacheData] forKey:indexNumber];
        }
    }
    
    //reload table
    NSIndexPath *indexPath  = [NSIndexPath indexPathForRow:index inSection:0];
    NSArray     *arr        = [NSArray arrayWithObject:indexPath];
    [table reloadRowsAtIndexPaths:arr withRowAnimation:NO];
}

-(void)didGetUserID:(NSNotification*)sender
{
    self.userID = sender.object;
    [[NSUserDefaults standardUserDefaults] setObject:userID forKey:USER_STORE_USER_ID];
    [manager getUserInfoWithUserID:[userID longLongValue]];
}

-(void)didGetUserInfo:(NSNotification*)sender
{
    User *aUser = sender.object;
    self.title = aUser.screenName;
}

-(void)didGetHomeLine:(NSNotification*)sender
{
    [self stopLoading];
    
    shouldLoadAvatar = YES;
    self.statuesArr = sender.object;
    [table reloadData];
    [[SHKActivityIndicator currentIndicator] hide];
    [self getImages];
}

-(void)refresh
{
    [manager getUserStatusUserID:userID sinceID:-1 maxID:-1 count:-1 page:-1 baseApp:-1 feature:-1];
}

//计算text field 的高度。
-(CGFloat)cellHeight:(NSString*)contentText with:(CGFloat)with
{
    UIFont * font=[UIFont  systemFontOfSize:14];
    CGSize size=[contentText sizeWithFont:font constrainedToSize:CGSizeMake(with - kTextViewPadding, 300000.0f) lineBreakMode:kLineBreakMode];
    CGFloat height = size.height + 44;
    return height;
}

#pragma mark - UITableViewDataSource
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [statuesArr count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger  row = indexPath.row;
    StatusCell *cell = [StatusCell cellForTableView:table fromNib:self.statusCellNib];
    
    if (row >= [statuesArr count]) {
        NSLog(@"cellForRowAtIndexPath error ,index = %d,count = %d",row,[statuesArr count]);
        return cell;
    }
    
    NSData *imageData = [imageDictionary objectForKey:[NSNumber numberWithInt:[indexPath row]]];
    NSData *avatarData = [headDictionary objectForKey:[NSNumber numberWithInt:[indexPath row]]];
    Status *status = [statuesArr objectAtIndex:row];
    cell.delegate = self;
    cell.cellIndexPath = indexPath;
    
    [cell setupCell:status avatarImageData:avatarData contentImageData:imageData];
    return cell;
}

#pragma mark - UITableViewDelegate
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath  
{
    NSInteger  row = indexPath.row;
    
    if (row >= [statuesArr count]) {
        NSLog(@"heightForRowAtIndexPath error ,index = %d,count = %d",row,[statuesArr count]);
        return 1;
    }
    
    Status *status          = [statuesArr objectAtIndex:row];
    Status *retwitterStatus = status.retweetedStatus;
    NSString *url = status.retweetedStatus.thumbnailPic;
    NSString *url2 = status.thumbnailPic;
    
    CGFloat height = 0.0f;
    
    //有转发的博文
    if (retwitterStatus && ![retwitterStatus isEqual:[NSNull null]])
    {
        height = [self cellHeight:status.text with:320.0f] + [self cellHeight:[NSString stringWithFormat:@"%@:%@",status.retweetedStatus.user.screenName,retwitterStatus.text] with:300.0f] - 22.0f;
    }
    
    //无转发的博文
    else
    {
        height = [self cellHeight:status.text with:320.0f];
    }
    
    //
    if ((url && [url length] != 0) || (url2 && [url2 length] != 0))
    {
        height = height + 80;
    }
    return height + 10;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger  row = indexPath.row;
    if (row >= [statuesArr count]) {
        NSLog(@"didSelectRowAtIndexPath error ,index = %d,count = %d",row,[statuesArr count]);
        return ;
    }
    
    ZJTDetailStatusVC *detailVC = [[ZJTDetailStatusVC alloc] initWithNibName:@"ZJTDetailStatusVC" bundle:nil];
    Status *status  = [statuesArr objectAtIndex:row];
    detailVC.status = status;
    
    NSData *data = [headDictionary objectForKey:[NSNumber numberWithInt:[indexPath row]]];
    detailVC.avatarImage = [UIImage imageWithData:data];
    
    NSData *imageData = [imageDictionary objectForKey:[NSNumber numberWithInt:[indexPath row]]];
    if (![imageData isEqual:[NSNull null]]) 
    {
        detailVC.contentImage = [UIImage imageWithData:imageData];
    }
    
    [self.navigationController pushViewController:detailVC animated:YES];
}

#pragma mark - StatusCellDelegate

-(void)getOriginImage:(NSNotification*) hhack
{
    NSDictionary * dic=hhack.object;
    NSString * url=[dic objectForKey:HHNetDataCacheURLKey];
    if ([url isEqualToString:browserView.bigImageURL]) 
    {
        [[SHKActivityIndicator currentIndicator] hide];
        shouldShowIndicator = NO;
        
        UIImage * img=[UIImage imageWithData:[dic objectForKey:HHNetDataCacheData]];
        [browserView.imageView setImage:img];
        
        NSLog(@"big url = %@",browserView.bigImageURL);
        if ([browserView.bigImageURL hasSuffix:@".gif"]) 
        {
            GifView *gifView = [[GifView alloc]initWithFrame:browserView.frame data:[dic objectForKey:HHNetDataCacheData]];
            gifView.userInteractionEnabled = NO;
            gifView.tag = GIF_VIEW_TAG;
            [browserView addSubview:gifView];
            [gifView release];
        }
    }
}

-(void)cellImageDidTaped:(StatusCell *)theCell image:(UIImage *)image
{
    shouldShowIndicator = YES;
    
    if ([theCell.cellIndexPath row] > [statuesArr count]) {
        NSLog(@"cellImageDidTaped error ,index = %d,count = %d",[theCell.cellIndexPath row],[statuesArr count]);
        return ;
    }
    
    Status *sts = [statuesArr objectAtIndex:[theCell.cellIndexPath row]];
    BOOL isRetwitter = sts.retweetedStatus && sts.retweetedStatus.originalPic != nil;
    UIApplication *app = [UIApplication sharedApplication];
    
    CGRect frame = CGRectMake(0, 0, 320, 480);
    if (browserView == nil) {
        self.browserView = [[[ImageBrowser alloc]initWithFrame:frame] autorelease];
        [browserView setUp];
    }
    
    browserView.image = image;
    browserView.delegate = self;
    browserView.bigImageURL = isRetwitter ? sts.retweetedStatus.originalPic : sts.originalPic;
    [browserView loadImage];
    
    app.statusBarHidden = YES;
    [app.keyWindow addSubview:browserView];
    
    //animation
    //    CAAnimation *anim = [ZJTHelpler animationWithOpacityFrom:0.0f To:1.0f Duration:0.3f BeginTime:0.0f];
    //    [browserView.layer addAnimation:anim forKey:@"jtone"];
    
    if (shouldShowIndicator == YES) {
        [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..."];
        [[SHKActivityIndicator currentIndicator] setRotationWithOritation:UIDeviceOrientationPortrait animted:NO];
        [[SHKActivityIndicator currentIndicator] hideAfterDelay:20];
    }
    else shouldShowIndicator = YES;
}


@end
