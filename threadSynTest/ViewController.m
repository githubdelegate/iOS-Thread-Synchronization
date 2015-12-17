//
//  ViewController.m
//  threadSynTest
//
//  Created by zhangyun on 15/12/16.
//  Copyright © 2015年 zhangyun. All rights reserved.
//

#import "ViewController.h"
#include "pthread.h"
#include "OSAtomic.h"

@interface ViewController ()<NSLocking>
{
    pthread_mutex_t mutex;
    int nslockInt;
    
    pthread_cond_t condition;
    BOOL ready_to_go;
    
    int timeToWork; //
    
}

@property (nonatomic,strong) NSMutableArray  *sharedArray;

@property (nonatomic,assign) int test;
@property (nonatomic,strong) NSLock *lock;
@property (nonatomic,strong) NSRecursiveLock *recursiveLock;
@property (nonatomic,strong) NSConditionLock  *conditionLock;
@property (nonatomic,strong) NSCondition  *condition; //
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.sharedArray = [NSMutableArray array];
    self.test = 10;
    ready_to_go = NO;
    
    pthread_mutex_init(&mutex,NULL);
    pthread_cond_init(&condition, NULL);
//    pthread_mutex_init(&mutex, NULL);
//    pthread_mutex_lock(&mutex);
//    [self changeValue];
//    printf("test=%d",self.test);
    
    self.lock = [NSLock new];
    self.recursiveLock = [NSRecursiveLock new];
    self.conditionLock = [[NSConditionLock alloc]initWithCondition:0];
    self.condition = [[NSCondition alloc] init];
}

- (void)changeValue{
    self.test+=10;
    NSLog(@"test==%d---current thread:%@",self.test,[NSThread currentThread]);
}

- (IBAction)btn1Click:(id)sender {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        pthread_mutex_lock(&mutex);
        [self changeValue];
        printf("test=%d\n",self.test);
        NSLog(@"current thread:%@",[NSThread currentThread]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            pthread_mutex_unlock(&mutex);
        });
    });
}

- (IBAction)nslock:(id)sender {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ([self.lock tryLock]) {
            [self changeValue];
            [self.lock unlock];
        }
        });
    
    [self.lock lock];
    [self changeValue];
//    [self.lock unlock];
}

- (IBAction)synchrinized:(id)sender {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @synchronized(self) {
            [self changeValue];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized(self) {
                [self changeValue];
            }
        });
    });
    
    @synchronized(self) {
        [self changeValue];
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    }
}

- (IBAction)nsrecursivelock:(id)sender {
    [self recursiveFun:10];
}

- (void)recursiveFun:(int)count
{
    [self.recursiveLock lock];
    [self changeValue];
    if (count != 0) {
        count--;
        [self recursiveFun:count];
    }
    
    [self.recursiveLock unlock];
}

- (void)sendSharedData{
    [self.conditionLock lock];
    [self.sharedArray addObject:@1];
    NSLog(@"添加数据 thread:%@",[NSThread currentThread]);
    [self.conditionLock unlockWithCondition:1];
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
}

- (IBAction)conditionlock:(id)sender {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (1) {
            [self.conditionLock lockWhenCondition:1];
            [self.sharedArray removeObjectAtIndex:0];
            NSLog(@"消耗一个数据 thread:%@",[NSThread currentThread]);
            BOOL isEmpty = self.sharedArray.count == 0 ? YES : NO;
            [self.conditionLock unlockWithCondition:(isEmpty ? 0 : 1)];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendSharedData) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] run];
    });
}

- (IBAction)distributedlock:(id)sender {

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self waitOnConditionfun];
    });

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self signalThreadCondition];
    });
}

// 实现生产者和消费者模式
- (IBAction)nscondition:(id)sender {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (1) {
            [self.condition lock];
            while (timeToWork <= 0) {
                [self.condition wait];
            }
            timeToWork--;
            NSLog(@"消费数据--thread:%@",[NSThread currentThread]);
            [self.condition unlock];
        }
    });

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (1) {
            [self.condition lock];
            timeToWork++;
            NSLog(@"添加数据--thread:%@",[NSThread currentThread]);
            [self.condition signal];
            [self.condition unlock];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    });
}

- (void)waitOnConditionfun{
    
    // mutex 如果等待线程先获得mutex，加锁。那signal如何获得锁，又如何加锁呢。哦如果不成功，直接就解锁
    pthread_mutex_lock(&mutex);
    while (ready_to_go) {
        NSLog(@"wait--thread:%@",[NSThread currentThread]);
        pthread_cond_wait(&condition, &mutex);
    }
    ready_to_go = false;
    pthread_mutex_unlock(&mutex);
}

- (void)signalThreadCondition{

    // At this point, there should be work for the other thread to do.
    pthread_mutex_lock(&mutex);
    ready_to_go = true;
    // Signal the other thread to begin work.
    pthread_cond_signal(&condition);
    NSLog(@"signal--thread:%@",[NSThread currentThread]);
    pthread_mutex_unlock(&mutex);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    pthread_mutex_unlock(&mutex);
    [self.lock unlock];
}

@end
