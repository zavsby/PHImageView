//
//  ProjectHelpers-Defs.h
//  testProject
//
//  Created by Sergey on 11.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifdef DEBUG
#   define ALog(fmt, ...) NSLog((@"%s " fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__);
#else
#   define ALog(...)
#endif