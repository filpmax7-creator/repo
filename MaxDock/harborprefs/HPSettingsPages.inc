
static NSString *HPText(NSString *english, NSString *arabic) {
    return HPUsesArabic() ? arabic : english;
}

- (void)loadView {
    self.view = [UIView new];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.semanticContentAttribute = HPUsesArabic()
        ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    NSArray *titles = @[@"MaxDock", HPText(@"Dock Modes", @"أوضاع الدوك"),
        HPText(@"Motion and Interaction", @"الحركة والتفاعل"),
        HPText(@"Icons and Layout", @"الأيقونات والتخطيط"),
        HPText(@"Appearance and Presets", @"المظهر والأنماط"), @"Support"];
    self.title = titles[self.page];
    self.navigationItem.backButtonTitle = HPText(@"Back", @"الرجوع");
    [self applyAppearance];
    [self buildPage];
}

- (void)applyAppearance {
    NSInteger index = [[self preferenceValueForKey:@"SettingsAppearance" defaultValue:@0] integerValue];
    self.overrideUserInterfaceStyle = index == 1 ? UIUserInterfaceStyleLight :
        (index == 2 ? UIUserInterfaceStyleDark : UIUserInterfaceStyleUnspecified);
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.backdrop.colors = dark ?
        @[(id)[UIColor colorWithRed:.09 green:.10 blue:.20 alpha:1].CGColor,
          (id)[UIColor colorWithRed:.15 green:.13 blue:.29 alpha:1].CGColor,
          (id)[UIColor colorWithRed:.07 green:.15 blue:.26 alpha:1].CGColor] :
        @[(id)[UIColor colorWithRed:.94 green:.93 blue:.99 alpha:1].CGColor,
          (id)[UIColor colorWithRed:.86 green:.87 blue:.98 alpha:1].CGColor,
          (id)[UIColor colorWithRed:.91 green:.95 blue:1 alpha:1].CGColor];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyAppearance];
    [self refreshDock];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (self.isViewLoaded && [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) {
        [self applyAppearance];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.backdrop.frame = self.view.bounds;
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, self.view.safeAreaInsets.bottom, 0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.pageScroll.contentInset, insets)) {
        self.pageScroll.contentInset = insets;
    }
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight secondary:(BOOL)secondary {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight]];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = secondary ? UIColor.secondaryLabelColor : UIColor.labelColor;
    label.numberOfLines = 0;
    return label;
}

- (UIStackView *)stack:(NSArray<UIView *> *)views axis:(UILayoutConstraintAxis)axis spacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = axis;
    stack.spacing = spacing;
    return stack;
}

- (void)pin:(UIView *)child to:(UIView *)parent inset:(CGFloat)inset {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:child];
    [NSLayoutConstraint activateConstraints:@[
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:inset],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-inset],
        [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:inset],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-inset]
    ]];
}

- (UIView *)card:(UIView *)body inset:(CGFloat)inset {
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    card.layer.cornerRadius = 17;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    card.layer.borderWidth = .5;
    card.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:.4].CGColor;
    [self pin:body to:card.contentView inset:inset];
    return card;
}

- (UIImage *)discordMark:(CGFloat)size {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef cg = context.CGContext;
        CGContextScaleCTM(cg, size / 24, size / 24);
        UIBezierPath *mark = [UIBezierPath bezierPath];
        [mark moveToPoint:CGPointMake(6, 5)];
        [mark addQuadCurveToPoint:CGPointMake(2, 16) controlPoint:CGPointMake(2, 10)];
        [mark addQuadCurveToPoint:CGPointMake(7, 19) controlPoint:CGPointMake(4, 18.5)];
        [mark addLineToPoint:CGPointMake(8.6, 17)];
        [mark addQuadCurveToPoint:CGPointMake(15.4, 17) controlPoint:CGPointMake(12, 19)];
        [mark addLineToPoint:CGPointMake(17, 19)];
        [mark addQuadCurveToPoint:CGPointMake(22, 16) controlPoint:CGPointMake(20, 18.5)];
        [mark addQuadCurveToPoint:CGPointMake(18, 5) controlPoint:CGPointMake(22, 10)];
        [mark addLineToPoint:CGPointMake(15.3, 4)];
        [mark addLineToPoint:CGPointMake(14.5, 6)];
        [mark addQuadCurveToPoint:CGPointMake(9.5, 6) controlPoint:CGPointMake(12, 5.5)];
        [mark addLineToPoint:CGPointMake(8.7, 4)];
        [mark closePath];
        [mark appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(7, 10, 3.7, 4.4)]];
        [mark appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(13.3, 10, 3.7, 4.4)]];
        mark.usesEvenOddFillRule = YES;
        [UIColor.whiteColor setFill];
        [mark fill];
    }];
}

- (UIView *)badge:(NSString *)symbol color:(UIColor *)color size:(CGFloat)size {
    UIView *badge = [UIView new];
    badge.backgroundColor = color;
    badge.layer.cornerRadius = size * .24;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    [badge.widthAnchor constraintEqualToConstant:size].active = YES;
    [badge.heightAnchor constraintEqualToConstant:size].active = YES;
    UIImage *image = [symbol isEqual:@"DiscordMark"] ? [self discordMark:size * .62] :
        [UIImage systemImageNamed:symbol withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:size * .48 weight:UIImageSymbolWeightSemibold]];
    if (image) {
        UIImageView *icon = [[UIImageView alloc] initWithImage:image];
        icon.contentMode = UIViewContentModeCenter;
        icon.tintColor = UIColor.whiteColor;
        [self pin:icon to:badge inset:0];
    } else {
        UILabel *initial = [self label:symbol size:size*.45 weight:UIFontWeightHeavy secondary:NO];
        initial.textColor = UIColor.whiteColor;
        initial.textAlignment = NSTextAlignmentCenter;
        [self pin:initial to:badge inset:0];
    }
    return badge;
}

- (UIView *)row:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon
          color:(UIColor *)color action:(void (^)(void))action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UILabel *name = [self label:title size:17 weight:UIFontWeightSemibold secondary:NO];
    NSMutableArray *labels = [NSMutableArray arrayWithObject:name];
    if (detail.length) [labels addObject:[self label:detail size:14 weight:UIFontWeightRegular secondary:YES]];
    UIStackView *copy = [self stack:labels axis:UILayoutConstraintAxisVertical spacing:2];
    UIImageView *arrow = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:HPUsesArabic() ? @"chevron.left" : @"chevron.right"]];
    arrow.tintColor = UIColor.tertiaryLabelColor;
    [arrow setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [self stack:@[[self badge:icon color:color size:36], copy, arrow]
                              axis:UILayoutConstraintAxisHorizontal spacing:12];
    row.alignment = UIStackViewAlignmentCenter;
    row.userInteractionEnabled = NO;
    [self pin:row to:button inset:10];
    button.accessibilityLabel = title;
    button.accessibilityValue = detail;
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *item) { action(); }]
     forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)hero:(NSString *)title subtitle:(NSString *)subtitle developer:(BOOL)developer {
    UILabel *name = [self label:title size:32 weight:UIFontWeightBold secondary:NO];
    UILabel *caption = [self label:subtitle size:17 weight:UIFontWeightMedium secondary:YES];
    name.textAlignment = caption.textAlignment = NSTextAlignmentCenter;
    UIView *icon = [self badge:developer ? @"F" : @"ellipsis.rectangle.fill" color:developer ?
        [UIColor colorWithRed:.16 green:.15 blue:.37 alpha:1] : UIColor.systemBlueColor size:86];
    if (developer) icon.layer.cornerRadius = 43;
    UIStackView *hero = [self stack:@[icon, name, caption] axis:UILayoutConstraintAxisVertical spacing:6];
    hero.alignment = UIStackViewAlignmentCenter;
    [hero setCustomSpacing:10 afterView:icon];
    return hero;
}

- (UIView *)preview {
    self.dockPreview = [UIView new];
    self.dockPreview.layer.cornerRadius = 24;
    self.dockPreview.layer.cornerCurve = kCACornerCurveContinuous;
    self.dockPreview.clipsToBounds = YES;
    self.dockPreview.backgroundColor = [UIColor.systemIndigoColor colorWithAlphaComponent:.15];
    self.dockMaterial = [UIVisualEffectView new];
    self.dockMaterial.clipsToBounds = YES;
    self.dockMaterial.layer.borderWidth = .65;
    self.dockMaterial.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:.6].CGColor;
    [self pin:self.dockMaterial to:self.dockPreview inset:12];
    NSArray *symbols = @[@"phone.fill", @"safari", @"message.fill", @"photo.fill", @"music.note"];
    NSArray *colors = @[UIColor.systemGreenColor, UIColor.systemBlueColor, UIColor.systemGreenColor,
                       UIColor.systemOrangeColor, UIColor.systemPinkColor];
    NSMutableArray *icons = [NSMutableArray new];
    for (NSUInteger i=0; i<symbols.count; i++) {
        [icons addObject:[self badge:symbols[i] color:colors[i] size:36]];
    }
    UIStackView *iconsRow = [self stack:icons axis:UILayoutConstraintAxisHorizontal spacing:5];
    iconsRow.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    iconsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dockMaterial.contentView addSubview:iconsRow];
    [NSLayoutConstraint activateConstraints:@[
        [iconsRow.centerXAnchor constraintEqualToAnchor:self.dockMaterial.contentView.centerXAnchor],
        [iconsRow.centerYAnchor constraintEqualToAnchor:self.dockMaterial.contentView.centerYAnchor],
        [self.dockPreview.heightAnchor constraintEqualToConstant:96]
    ]];
    [self refreshDock];
    self.dockPreview.accessibilityLabel = HPText(@"Dock preview", @"معاينة الدوك");
    return self.dockPreview;
}

- (void)refreshDock {
    if (!self.dockMaterial) return;
    BOOL glass = [self getGlassBackground:nil].boolValue;
    UIVisualEffect *effect = nil;
    if (glass && !UIAccessibilityIsReduceTransparencyEnabled()) {
        if (@available(iOS 26.0, *)) {
            Class glassClass = NSClassFromString(@"UIGlassEffect");
            SEL selector = NSSelectorFromString(@"effectWithStyle:");
            if ([glassClass respondsToSelector:selector]) {
                effect = ((UIVisualEffect *(*)(id, SEL, NSInteger))objc_msgSend)(glassClass, selector, 0);
            }
        }
        if (!effect) effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    self.dockMaterial.effect = effect;
    CGFloat opacity = [self getGlassOpacity:nil].doubleValue;
    self.dockMaterial.contentView.backgroundColor = [UIColor.secondarySystemBackgroundColor
        colorWithAlphaComponent:effect ? opacity * .45 : 1];
    self.dockMaterial.layer.cornerRadius = MAX(8, MIN(32,
        [[self preferenceValueForKey:@"GlassCornerRadius" defaultValue:@24] doubleValue]));
}

- (NSDictionary *)settingsItems {
    NSURL *url = [[NSBundle bundleForClass:HPRootListController.class] URLForResource:@"Root" withExtension:@"plist"];
    NSArray *items = [NSDictionary dictionaryWithContentsOfURL:url][@"items"];
    NSMutableDictionary *map = [NSMutableDictionary new];
    for (NSDictionary *item in items) {
        NSString *key = item[@"key"] ?: item[@"action"];
        if (key) map[key] = item;
    }
    return map;
}

- (UIView *)control:(NSDictionary *)item {
    NSString *title = HPLocalized(item[@"label"]);
    NSString *key = item[@"key"];
    __weak HPRootListController *weakSelf = self;
    if (item[@"action"]) {
        SEL action = NSSelectorFromString(item[@"action"]);
        return [self row:title detail:nil icon:@"slider.horizontal.3" color:UIColor.systemBlueColor action:^{
            HPRootListController *controller = weakSelf;
            if ([controller respondsToSelector:action]) {
                ((void (*)(id, SEL))objc_msgSend)(controller, action);
            }
        }];
    }
    BOOL toggle = [item[@"cell"] isEqual:@"PSSwitchCell"];
    SEL getter = item[@"get"] ? NSSelectorFromString(item[@"get"]) : NULL;
    SEL setter = item[@"set"] ? NSSelectorFromString(item[@"set"]) : NULL;
    NSNumber *value = getter && [self respondsToSelector:getter] ?
        ((id (*)(id, SEL, id))objc_msgSend)(self, getter, nil) :
        [self preferenceValueForKey:key defaultValue:item[@"default"]];
    void (^save)(NSNumber *) = ^(NSNumber *number) {
        HPRootListController *controller = weakSelf;
        if (setter && [controller respondsToSelector:setter]) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(controller, setter, number, nil);
        } else {
            [controller setValue:number forPreferenceKey:key];
        }
        [controller refreshDock];
    };
    UILabel *label = [self label:title size:16 weight:UIFontWeightSemibold secondary:NO];
    if (toggle) {
        UISwitch *control = [UISwitch new];
        control.on = value.boolValue;
        control.onTintColor = UIColor.systemBlueColor;
        control.accessibilityLabel = title;
        [control setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [control addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
            save(@(((UISwitch *)action.sender).on));
        }] forControlEvents:UIControlEventValueChanged];
        UIStackView *row = [self stack:@[label, control] axis:UILayoutConstraintAxisHorizontal spacing:10];
        row.alignment = UIStackViewAlignmentCenter;
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:42].active = YES;
        return row;
    }
    UISlider *slider = [UISlider new];
    slider.minimumValue = [item[@"min"] floatValue];
    slider.maximumValue = [item[@"max"] floatValue];
    slider.value = value.floatValue;
    slider.continuous = NO;
    slider.accessibilityLabel = title;
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = [key isEqual:@"DockCapacity"] ? 0 : 2;
    UILabel *reading = [self label:[formatter stringFromNumber:@(slider.value)]
                              size:14 weight:UIFontWeightMedium secondary:YES];
    [reading setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [slider addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        float position = ((UISlider *)action.sender).value;
        NSNumber *number = [key isEqual:@"DockCapacity"] ? @((NSInteger)roundf(position)) : @(position);
        reading.text = [formatter stringFromNumber:number];
        save(number);
    }] forControlEvents:UIControlEventValueChanged];
    return [self stack:@[[self stack:@[label, reading] axis:UILayoutConstraintAxisHorizontal spacing:8], slider]
                   axis:UILayoutConstraintAxisVertical spacing:3];
}

- (void)addControls:(NSArray<NSString *> *)keys {
    NSDictionary *items = [self settingsItems];
    NSMutableArray *views = [NSMutableArray new];
    for (NSString *key in keys) {
        if (items[key]) [views addObject:[self control:items[key]]];
    }
    [self.content addArrangedSubview:[self card:[self stack:views axis:UILayoutConstraintAxisVertical spacing:10] inset:13]];
}

- (void)openPage:(NSInteger)page {
    HPRootListController *controller = [HPRootListController new];
    controller.page = page;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)reloadSettingsPage {
    CGPoint offset = self.pageScroll.contentOffset;
    [self.pageScroll removeFromSuperview];
    [self.backdrop removeFromSuperlayer];
    self.dockPreview = nil;
    self.dockMaterial = nil;
    [self buildPage];
    [self.view layoutIfNeeded];
    [self.pageScroll setContentOffset:offset animated:NO];
}

- (void)buildPage {
    self.backdrop = [CAGradientLayer layer];
    self.backdrop.startPoint = CGPointMake(0,0);
    self.backdrop.endPoint = CGPointMake(1,1);
    [self.view.layer insertSublayer:self.backdrop atIndex:0];
    [self applyAppearance];
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    self.pageScroll = scroll;
    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    scroll.contentInset = UIEdgeInsetsMake(0, 0, self.view.safeAreaInsets.bottom, 0);
    self.content = [self stack:@[] axis:UILayoutConstraintAxisVertical spacing:13];
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:self.content];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    UILayoutGuide *area = scroll.contentLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.content.topAnchor constraintEqualToAnchor:area.topAnchor constant:16],
        [self.content.bottomAnchor constraintEqualToAnchor:area.bottomAnchor constant:-30],
        [self.content.leadingAnchor constraintEqualToAnchor:area.leadingAnchor constant:14],
        [self.content.trailingAnchor constraintEqualToAnchor:area.trailingAnchor constant:-14],
        [self.content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-28]
    ]];
    switch (self.page) {
        case 1: [self addControls:@[@"chooseDockMode",@"CircularSpeed",@"CircularIconScale"]]; break;
        case 2: [self addControls:@[@"chooseNormalMotion",@"NormalMotionStrength",@"LaunchOnRelease",@"ShowAppName",
            @"HapticFeedback",@"SelectionGlow",@"LaunchBounce",@"BadgeBounce",@"EffectiveRange",
            @"EvasionDistance",@"AnimationDuration"]]; break;
        case 3: [self addControls:@[@"DockVerticalOffset",@"DockPositionHandle",@"IconSizeScale",@"MaximumScale",
            @"ExtraDockApps",@"DockCapacity",@"IconInset",@"IconPaddingMultiplier",@"HideHomeSearch",@"AutoHideDock",
            @"resetLayoutDefaults",@"respring"]]; break;
        case 4: [self buildAppearance]; break;
        case 5: [self buildSupport]; break;
        default: [self buildHome]; break;
    }
}

- (void)buildHome {
    [self.content addArrangedSubview:[self hero:@"MaxDock" subtitle:HPText(@"Your dock, your way", @"الدوك بطريقتك") developer:NO]];
    [self addControls:@[@"Enabled"]];
    [self.content addArrangedSubview:[self preview]];
    NSArray *names = @[HPText(@"Dock Modes", @"أوضاع الدوك"), HPText(@"Motion and Interaction", @"الحركة والتفاعل"),
        HPText(@"Icons and Layout", @"الأيقونات والتخطيط"), HPText(@"Appearance and Presets", @"المظهر والأنماط"), @"Support"];
    NSArray *icons = @[@"square.3.layers.3d", @"play.fill", @"square.grid.2x2.fill", @"paintbrush.fill", @"headphones"];
    NSArray *colors = @[UIColor.systemBlueColor, UIColor.systemPurpleColor, UIColor.systemGreenColor,
                        UIColor.systemIndigoColor, UIColor.systemBlueColor];
    NSMutableArray *rows = [NSMutableArray new];
    __weak HPRootListController *weakSelf = self;
    for (NSUInteger i=0; i<names.count; i++) {
        NSString *detail = i == 0 ? HPText(@"Normal · Circular · Swipe", @"طبيعي • دائري • سحب") :
            (i == 4 ? HPText(@"Contact the developer", @"تواصل مع المطور") : nil);
        [rows addObject:[self row:names[i] detail:detail icon:icons[i] color:colors[i] action:^{
            [weakSelf openPage:i+1];
        }]];
        if (i+1 < names.count) {
            UIView *line = [UIView new];
            line.backgroundColor = UIColor.separatorColor;
            [line.heightAnchor constraintEqualToConstant:.5].active = YES;
            [rows addObject:line];
        }
    }
    [self.content addArrangedSubview:[self card:[self stack:rows axis:UILayoutConstraintAxisVertical spacing:0] inset:4]];
    UILabel *credit = [self label:@"Developed by Filp Max" size:14 weight:UIFontWeightRegular secondary:YES];
    credit.textAlignment = NSTextAlignmentCenter;
    [self.content addArrangedSubview:credit];
}

- (UIView *)presetThumbnail:(NSUInteger)index {
    UIView *surface = [UIView new];
    surface.layer.cornerRadius = 10;
    surface.backgroundColor = index == 0 ? [UIColor colorWithRed:.12 green:.10 blue:.26 alpha:1] :
        [UIColor.systemIndigoColor colorWithAlphaComponent:index == 1 ? .13 : .25];
    [surface.heightAnchor constraintEqualToConstant:48].active = YES;
    NSArray *symbols = @[@"phone.fill", @"safari", @"message.fill", @"music.note"];
    NSArray *colors = @[UIColor.systemGreenColor, UIColor.systemBlueColor, UIColor.systemMintColor, UIColor.systemPinkColor];
    NSMutableArray *icons = [NSMutableArray new];
    CGFloat size = index == 1 ? 10 : 12;
    for (NSUInteger i=0; i<symbols.count; i++) {
        [icons addObject:[self badge:symbols[i] color:colors[i] size:size]];
    }
    UIView *dock = [self card:[self stack:icons axis:UILayoutConstraintAxisHorizontal spacing:2] inset:3];
    dock.translatesAutoresizingMaskIntoConstraints = NO;
    [surface addSubview:dock];
    [NSLayoutConstraint activateConstraints:@[
        [surface.widthAnchor constraintEqualToConstant:65],
        [dock.centerXAnchor constraintEqualToAnchor:surface.centerXAnchor],
        [dock.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor]
    ]];
    return surface;
}

- (void)buildAppearance {
    [self.content addArrangedSubview:[self preview]];
    NSDictionary *items = [self settingsItems];
    NSMutableDictionary *glass = [items[@"GlassDockBackground"] mutableCopy];
    glass[@"label"] = HPText(@"Glass Appearance", @"المظهر الزجاجي");
    [self.content addArrangedSubview:[self card:[self control:glass] inset:12]];
    UISegmentedControl *appearance = [[UISegmentedControl alloc] initWithItems:
        @[HPText(@"Automatic",@"تلقائي"), HPText(@"Light",@"فاتح"), HPText(@"Dark",@"داكن")]];
    appearance.selectedSegmentIndex = MAX(0, MIN(2, [[self preferenceValueForKey:@"SettingsAppearance" defaultValue:@0] integerValue]));
    __weak HPRootListController *weakSelf = self;
    [appearance addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [weakSelf setValue:@(((UISegmentedControl *)action.sender).selectedSegmentIndex) forPreferenceKey:@"SettingsAppearance"];
        [weakSelf applyAppearance];
    }] forControlEvents:UIControlEventValueChanged];
    [self.content addArrangedSubview:[self card:appearance inset:8]];
    [self.content addArrangedSubview:[self label:HPText(@"Presets",@"الأنماط") size:20 weight:UIFontWeightBold secondary:NO]];
    NSArray *names = @[HPText(@"Gaming",@"الألعاب"), HPText(@"Compact",@"المضغوط"), @"macOS"];
    NSArray *colors = @[UIColor.systemPurpleColor, UIColor.systemGrayColor, UIColor.systemBlueColor];
    NSMutableArray *buttons = [NSMutableArray new];
    for (NSUInteger i=0; i<names.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.layer.cornerRadius = 13;
        button.backgroundColor = [colors[i] colorWithAlphaComponent:i == 0 ? .24 : .13];
        UILabel *label = [self label:names[i] size:14 weight:UIFontWeightSemibold secondary:NO];
        label.textAlignment = NSTextAlignmentCenter;
        UIStackView *tile = [self stack:@[[self presetThumbnail:i],label]
                                    axis:UILayoutConstraintAxisVertical spacing:8];
        tile.alignment = UIStackViewAlignmentCenter;
        tile.userInteractionEnabled = NO;
        [self pin:tile to:button inset:10];
        button.accessibilityLabel = names[i];
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
            HPRootListController *controller = weakSelf;
            if (i == 0) [controller applyGamingProfile];
            if (i == 1) [controller applyCompactProfile];
            if (i == 2) [controller applyMacOSProfile];
            [controller setValue:@(i) forPreferenceKey:@"SettingsSelectedPreset"];
            [controller reloadSettingsPage];
        }] forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:button];
    }
    self.presetButtons = buttons;
    [self updatePresetSelection];
    UIStackView *presets = [self stack:buttons axis:UILayoutConstraintAxisHorizontal spacing:7];
    presets.distribution = UIStackViewDistributionFillEqually;
    [self.content addArrangedSubview:[self card:presets inset:9]];
    NSMutableDictionary *opacity = [items[@"GlassOpacity"] mutableCopy];
    opacity[@"label"] = HPText(@"Background opacity", @"شفافية الخلفية");
    NSDictionary *radius = @{@"label":HPText(@"Corner radius",@"استدارة الحواف"),
        @"key":@"GlassCornerRadius",@"min":@8,@"max":@32,@"default":@24};
    [self.content addArrangedSubview:[self card:[self stack:@[[self control:opacity], [self control:radius]]
        axis:UILayoutConstraintAxisVertical spacing:10] inset:13]];
    [self addControls:@[@"HideDockBackground",@"SlimAdaptiveBackground",@"applyTransparentProfile"]];
}

- (void)updatePresetSelection {
    NSInteger selected = [[self preferenceValueForKey:@"SettingsSelectedPreset" defaultValue:@(-1)] integerValue];
    [self.presetButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, BOOL *stop) {
        BOOL active = selected == (NSInteger)index;
        button.layer.borderWidth = active ? 2 : 0;
        button.layer.borderColor = UIColor.systemBlueColor.CGColor;
        button.accessibilityTraits = UIAccessibilityTraitButton | (active ? UIAccessibilityTraitSelected : 0);
    }];
}

- (void)buildSupport {
    [self.content addArrangedSubview:[self card:[self hero:@"Filp Max"
        subtitle:HPText(@"MaxDock Developer",@"مطور MaxDock") developer:YES] inset:18]];
    NSArray *names = @[@"X",@"Discord",HPText(@"Email",@"البريد الإلكتروني")];
    NSArray *details = @[@"@maxlco1",HPText(@"Contact on Discord",@"تواصل عبر Discord"),@"filpmax7@gmail.com"];
    NSArray *links = @[@"https://x.com/maxlco1?s=11",@"https://discord.com/users/1343028389950390272",@"mailto:filpmax7@gmail.com"];
    NSArray *symbols = @[@"𝕏",@"DiscordMark",@"envelope"];
    NSArray *colors = @[UIColor.blackColor,[UIColor colorWithRed:.35 green:.39 blue:.95 alpha:1],UIColor.systemBlueColor];
    __weak HPRootListController *weakSelf = self;
    for (NSUInteger i=0; i<names.count; i++) {
        UIView *link = [self row:names[i] detail:details[i] icon:symbols[i] color:colors[i] action:^{
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:links[i]] options:@{} completionHandler:^(BOOL opened) {
                if (opened) return;
                HPRootListController *controller = weakSelf;
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:names[i] message:links[i] preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:HPText(@"Copy",@"نسخ") style:UIAlertActionStyleDefault handler:^(UIAlertAction *item) {
                    UIPasteboard.generalPasteboard.string = links[i];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:HPLocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
                [controller presentViewController:alert animated:YES completion:nil];
            }];
        }];
        [self.content addArrangedSubview:[self card:link inset:6]];
    }
    UILabel *thanks = [self label:HPText(@"Thanks for supporting MaxDock.",@"شكراً لدعمك وتطوير MaxDock")
                             size:16 weight:UIFontWeightMedium secondary:YES];
    thanks.textAlignment = NSTextAlignmentCenter;
    [self.content addArrangedSubview:thanks];
}
