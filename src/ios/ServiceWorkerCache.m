/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "ServiceWorkerCache.h"

@implementation ServiceWorkerCache

@dynamic name;
@dynamic scope;
@dynamic entries;


-(NSString *)urlWithoutQueryForUrl:(NSURL *)url
{
    NSURL *absoluteURL = [url absoluteURL];
    NSURL *urlWithoutQuery;
    if ([absoluteURL scheme] == nil) {
        NSString *path = [absoluteURL path];
        NSRange queryRange = [path rangeOfString:@"?"];
        if (queryRange.location != NSNotFound) {
            path = [path substringToIndex:queryRange.location];
        }
        return path;
    }
    urlWithoutQuery = [[NSURL alloc] initWithScheme:[[absoluteURL scheme] lowercaseString]
                                               host:[[absoluteURL host] lowercaseString]
                                               path:[absoluteURL path]];
    return [urlWithoutQuery absoluteString];
}

-(NSArray *)entriesMatchingRequestByURL:(NSURL *)url includesQuery:(BOOL)includesQuery inContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"CacheEntry" inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];

    NSPredicate *predicate;
    
    if (includesQuery) {
        predicate = [NSPredicate predicateWithFormat:@"(url == %@) AND (query == %@)", [self urlWithoutQueryForUrl:url], url.query];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(url == %@)", [self urlWithoutQueryForUrl:url]];
    }
    [fetchRequest setPredicate:predicate];

    NSError *error;
    NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
    
    // TODO: check error on entries == nil
    return entries;
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request inContext:(NSManagedObjectContext *)moc
{
    return [self matchForRequest:request withOptions:@{} inContext:moc];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options inContext:(NSManagedObjectContext *)moc
{
    BOOL query = [options[@"includeQuery"] boolValue];
    NSArray *entries = [self entriesMatchingRequestByURL:request.URL includesQuery:query inContext:moc];
    
    if (entries == nil || entries.count == 0) {
        return nil;
    }
    
    for (ServiceWorkerCacheEntry *entry in entries) {
        NSURLRequest *cachedRequest = (NSURLRequest *)[NSKeyedUnarchiver unarchiveObjectWithData:entry.request];
        NSString *varyHeader = [cachedRequest valueForHTTPHeaderField:@"Vary"];
        if (varyHeader != nil) {
            
        }
    }
    ServiceWorkerCacheEntry *bestEntry = (ServiceWorkerCacheEntry *)entries[0];
    ServiceWorkerResponse *bestResponse = (ServiceWorkerResponse *)[NSKeyedUnarchiver unarchiveObjectWithData:bestEntry.response];
    return bestResponse;
}

-(void)putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response inContext:(NSManagedObjectContext *)moc
{
    ServiceWorkerCacheEntry *entry = (ServiceWorkerCacheEntry *)[NSEntityDescription insertNewObjectForEntityForName:@"CacheEntry"
     inManagedObjectContext:moc];
    entry.url = [self urlWithoutQueryForUrl:request.URL];
    entry.query = request.URL.query;
    entry.request = [NSKeyedArchiver archivedDataWithRootObject:request];
    entry.response = [NSKeyedArchiver archivedDataWithRootObject:response];
    entry.cache = self;
    NSError *err;
    [moc save:&err];
}

-(bool)deleteRequest:(NSURLRequest *)request fromContext:(NSManagedObjectContext *)moc
{
    NSArray *entries = [self entriesMatchingRequestByURL:request.URL includesQuery:NO inContext:moc];
    
    bool requestExistsInCache = ([entries count] > 0);
    if (requestExistsInCache) {
        [moc deleteObject:entries[0]];
    }
    return requestExistsInCache;
}

-(NSArray *)requestsFromContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"CacheEntry" inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];
    NSError *error;
    NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
    
    return entries;
}


@end
