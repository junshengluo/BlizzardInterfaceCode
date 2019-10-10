
local BIDS_TAB_ID = 2;


AuctionHouseAuctionsFrameTabMixin = {};

function AuctionHouseAuctionsFrameTabMixin:OnClick()
	AuctionHouseFrameTopTabMixin.OnClick(self);

	self:GetParent():SetTab(self:GetID());
end


AuctionHouseAuctionsSummaryListMixin = {};

function AuctionHouseAuctionsSummaryListMixin:OnLoad()
	AuctionHouseBackgroundMixin.OnLoad(self);

	self.InsetFrame:Hide();
	self.SelectedHighlight:SetAtlas("auctionhouse-ui-row-select", true);
	self.SelectedHighlight:SetBlendMode("ADD");
	self.SelectedHighlight:SetAlpha(0.8);
end


AuctionHouseAuctionsSummaryLineMixin = {};

function AuctionHouseAuctionsSummaryLineMixin:InitLine(auctionsFrame)
	self.auctionsFrame = auctionsFrame;
end

function AuctionHouseAuctionsSummaryLineMixin:OnLoad()
	self:SetNormalTexture(nil);
	self.Text:ClearAllPoints();
	self.Text:SetPoint("LEFT", self.Icon, "RIGHT", 4, 0);
	self.Text:SetPoint("RIGHT", -4, 0);
	self.Text:SetFontObject(Number13FontYellow);
end

function AuctionHouseAuctionsSummaryLineMixin:OnEvent(event, ...)
	if event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
		local itemID = ...;
		if itemID == self.pendingItemID then
			self:UpdateDisplay();
		end
	end
end

function AuctionHouseAuctionsSummaryLineMixin:OnHide()
	self:UnregisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED");
end

function AuctionHouseAuctionsSummaryLineMixin:UpdateDisplay()
	self.Icon:Hide();

	local listIndex = self:GetListIndex();
	local isDisplayingBids = self.auctionsFrame:IsDisplayingBids();
	if listIndex == 1 then
		self.Text:SetText(isDisplayingBids and AUCTION_HOUSE_ALL_BIDS or AUCTION_HOUSE_ALL_AUCTIONS);
		self.Text:SetPoint("LEFT", 4, 0);
	else
		self.Text:SetPoint("LEFT", self.Icon, "RIGHT", 4, 0);

		local typeIndex = listIndex - 1;
		local itemKey = isDisplayingBids and C_AuctionHouse.GetBidType(typeIndex) or C_AuctionHouse.GetOwnedAuctionType(typeIndex);
		local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey);
		if not itemKeyInfo then
			self.pendingItemID = itemKey.itemID;
			self:RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED");
			self.Text:SetText("");
			return;
		end

		self.Icon:Show();
		self.Icon:SetTexture(itemKeyInfo.iconFileID);
		self.Text:SetText(AuctionHouseUtil.GetItemDisplayTextFromItemKey(itemKey, itemKeyInfo));
	end

	if self.pendingItemID ~= nil then
		self:UnregisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED");
		self.pendingItemID = nil;
	end
end


AuctionHouseBidsSummaryLineMixin = {};

function AuctionHouseBidsSummaryLineMixin:OnEvent(event, ...)
	if event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
		local itemID = ...;
		if itemID == self.pendingItemID then
			self:UpdateDisplay();
		end
	end
end

function AuctionHouseBidsSummaryLineMixin:OnHide()
	self:UnregisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED");
end

function AuctionHouseBidsSummaryLineMixin:UpdateDisplay()
	local listIndex = self:GetListIndex();
	if listIndex == 1 then
		self.Text:SetText(AUCTION_HOUSE_ALL_BIDS);
	else
		local typeOffset = listIndex - 1;
		local itemKey = C_AuctionHouse.GetBidType(typeOffset);
		local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey);
		if not itemKeyInfo then
			self.pendingItemID = itemKey.itemID;
			self:RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED");
			self.Text:SetText("");
			return;
		end

		self.Text:SetText(AuctionHouseUtil.GetItemDisplayTextFromItemKey(itemKey, itemKeyInfo));
	end

	if self.pendingItemID ~= nil then
		self:UnregisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED");
		self.pendingItemID = nil;
	end
end


CancelAuctionButtonMixin = {};

function CancelAuctionButtonMixin:OnClick()
	local auctionsFrame = self:GetParent();
	auctionsFrame:CancelSelectedAuction();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end


AuctionHouseAuctionsFrameMixin = CreateFromMixins(AuctionHouseBuySystemMixin, AuctionHouseSortOrderSystemMixin);

local AUCTIONS_FRAME_EVENTS = {
	"OWNED_AUCTIONS_UPDATED",
	"OWNED_AUCTION_ADDED",
	"OWNED_AUCTION_EXPIRED",
	"ITEM_SEARCH_RESULTS_UPDATED",
	"ITEM_SEARCH_RESULTS_ADDED",
	"BIDS_UPDATED",
	"BID_ADDED",
	"AUCTION_CANCELED",
};

local AuctionsFrameDisplayMode = {
	AllAuctions = 1,
	BidsList = 2,
	Item = 3,
	Commodity = 4,
};

function AuctionHouseAuctionsFrameMixin:OnLoad()
	AuctionHouseBuySystemMixin.OnLoad(self);
	AuctionHouseSortOrderSystemMixin.OnLoad(self);

	self.numTabs = 2;
	self:SetTab(1);

	self.ItemDisplay:SetAuctionHouseFrame(self:GetAuctionHouseFrame());

	self:InitializeSummaryList();
	self:InitializeAllAuctionsList();
	self:InitializeBidsList();
	self:InitializeItemList();
	self:InitializeCommoditiesList();

	self:SetDisplayMode(AuctionsFrameDisplayMode.AllAuctions);
end

function AuctionHouseAuctionsFrameMixin:OnShow()
	FrameUtil.RegisterFrameForEvents(self, AUCTIONS_FRAME_EVENTS);
	self:RefreshSeachResults();
end

function AuctionHouseAuctionsFrameMixin:RefreshSeachResults()
	if self:IsDisplayingBids() then
		self:GetAuctionHouseFrame():QueryAll(AuctionHouseSearchContext.AllBids);
	else
		self:GetAuctionHouseFrame():QueryAll(AuctionHouseSearchContext.AllAuctions);
	end

	local displayMode = self:GetDisplayMode();
	local itemKey = self:GetItemKey();
	if itemKey then
		self:GetAuctionHouseFrame():QueryItem(self:GetSearchContext(), itemKey);
		if displayMode == AuctionsFrameDisplayMode.Item then
			self.ItemList:DirtyScrollFrame();
		elseif displayMode == AuctionsFrameDisplayMode.Commodity then
			self.CommoditiesList:DirtyScrollFrame();
		end
	end
end

function AuctionHouseAuctionsFrameMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, AUCTIONS_FRAME_EVENTS);
end

function AuctionHouseAuctionsFrameMixin:OnEvent(event, ...)
	if event == "OWNED_AUCTIONS_UPDATED" then
		self.AllAuctionsList:Reset();
		self.SummaryList:RefreshScrollFrame();
	elseif event == "OWNED_AUCTION_ADDED" then
		local ownedAuctionID = ...;

		-- TODO:: Support updating the AllAuctions list

		self.SummaryList:RefreshScrollFrame();
	elseif event == "OWNED_AUCTION_EXPIRED" then
		local ownedAuctionID = ...;
		
		-- TODO:: Support updating the AllAuctions list

		self.SummaryList:RefreshScrollFrame();
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
		self.ItemList:DirtyScrollFrame();
	elseif event == "ITEM_SEARCH_RESULTS_ADDED" then
		self.ItemList:DirtyScrollFrame();
	elseif event == "BIDS_UPDATED" then
		self.BidsList:DirtyScrollFrame();

		if self:IsDisplayingBids() then
			self.SummaryList:RefreshScrollFrame();
		end

	elseif event == "BID_ADDED" then
		self.BidsList:DirtyScrollFrame();

		if self:IsDisplayingBids() then
			self.SummaryList:RefreshScrollFrame();
		end
	elseif event == "AUCTION_CANCELED" then
		self:RefreshSeachResults();
	end
end

function AuctionHouseAuctionsFrameMixin:InitializeSummaryList()
	self.SummaryList:SetSelectedListIndex(1);

	local function OnSummaryLineSelectedCallback(...)
		self:OnSummaryLineSelected(...);
	end

	self.SummaryList:SetSelectionCallback(OnSummaryLineSelectedCallback);
	self.SummaryList:SetLineTemplate("AuctionHouseAuctionsSummaryLineTemplate", self);
end

function AuctionHouseAuctionsFrameMixin:InitializeAllAuctionsList()
	self.AllAuctionsList:SetSelectionCallback(function(searchResult)
		self:OnAllAuctionsSearchResultSelected(searchResult);
	end);

	self.AllAuctionsList:SetHighlightCallback(function(currentRowData, selectedRowData)
		return selectedRowData and currentRowData.auctionID == selectedRowData.auctionID;
	end);

	self.AllAuctionsList:SetTableBuilderLayout(AuctionHouseTableBuilder.GetAllAuctionsLayout(self, self.AllAuctionsList));

	local function AuctionsSearchStarted()
		return true;
	end

	self.AllAuctionsList:SetDataProvider(AuctionsSearchStarted, C_AuctionHouse.GetOwnedAuctionInfo, C_AuctionHouse.GetNumOwnedAuctions, C_AuctionHouse.HasFullOwnedAuctionResults);

	
	local function AllAuctionsRefreshResults()
		self:GetAuctionHouseFrame():QueryAll(AuctionHouseSearchContext.AllAuctions);
		self.AllAuctionsList:DirtyScrollFrame();
	end

	local AllAuctionsGetTotalQuantity = nil;

	self.AllAuctionsList:SetRefreshFrameFunctions(AllAuctionsGetTotalQuantity, AllAuctionsRefreshResults);
end

function AuctionHouseAuctionsFrameMixin:InitializeBidsList()
	self.BidsList:SetSelectionCallback(function(searchResult)
		self:OnBidsListSearchResultSelected(searchResult);
	end);

	self.BidsList:SetHighlightCallback(function(currentRowData, selectedRowData)
		return selectedRowData and currentRowData.auctionID == selectedRowData.auctionID;
	end);

	self.BidsList:SetTableBuilderLayout(AuctionHouseTableBuilder.GetBidsListLayout(self, self.BidsList));

	local function BidsSearchStarted()
		return true;
	end

	self.BidsList:SetDataProvider(BidsSearchStarted, C_AuctionHouse.GetBidInfo, C_AuctionHouse.GetNumBids, C_AuctionHouse.HasFullBidResults);

	
	local function BidsListRefreshResults()
		self:GetAuctionHouseFrame():QueryAll(AuctionHouseSearchContext.AllBids);
		self.BidsList:DirtyScrollFrame();
	end

	local BidsListGetTotalQuantity = nil;

	self.BidsList:SetRefreshFrameFunctions(BidsListGetTotalQuantity, BidsListRefreshResults);
end

function AuctionHouseAuctionsFrameMixin:InitializeItemList()
	self.ItemList:SetTableBuilderLayout(AuctionHouseTableBuilder.GetAuctionsItemListLayout(self, self.ItemList));

	self.ItemList:SetSelectionCallback(function(searchResult)
		self:OnItemSearchResultSelected(searchResult);
	end);

	self.ItemList:SetHighlightCallback(function(currentRowData, selectedRowData)
		return selectedRowData and currentRowData.auctionID == selectedRowData.auctionID;
	end);

	self.ItemList:SetLineOnEnterCallback(AuctionHouseUtil.SetAuctionHouseTooltip);
	self.ItemList:SetLineOnLeaveCallback(GameTooltip_Hide);

	local function AuctionsItemListSearchStarted()
		return self.itemKey ~= nil;
	end

	local function AuctionsItemListGetEntry(index)
		return self.itemKey and C_AuctionHouse.GetItemSearchResultInfo(self.itemKey, index);
	end

	local function AuctionsItemListGetNumEntries()
		return self.itemKey and C_AuctionHouse.GetNumItemSearchResults(self.itemKey) or 0;
	end

	local function AuctionsItemListHasFullResults()
		return self.itemKey == nil or C_AuctionHouse.HasFullItemSearchResults(self.itemKey);
	end

	self.ItemList:SetDataProvider(AuctionsItemListSearchStarted, AuctionsItemListGetEntry, AuctionsItemListGetNumEntries, AuctionsItemListHasFullResults);


	local function AuctionsItemListGetTotalQuantity()
		return self.itemKey and C_AuctionHouse.GetItemSearchResultsQuantity(self.itemKey) or 0;
	end

	local function AuctionsItemListRefreshResults()
		if self.itemKey ~= nil then
			C_AuctionHouse.RefreshItemSearchResults(self.itemKey);
		end
	end

	self.ItemList:SetRefreshFrameFunctions(AuctionsItemListGetTotalQuantity, AuctionsItemListRefreshResults);
end

function AuctionHouseAuctionsFrameMixin:InitializeCommoditiesList()
	self.CommoditiesList:SetTableBuilderLayout(AuctionHouseTableBuilder.GetCommoditiesAuctionsListLayout(self, self.CommoditiesList));

	self.CommoditiesList:SetHighlightCallback(function(currentRowData, selectedRowData)
		return selectedRowData and currentRowData.auctionID == selectedRowData.auctionID;
	end);

	self.CommoditiesList:SetSelectionCallback(function(commoditySearchResult)
		self:OnCommoditySearchResultSelected(commoditySearchResult);
	end);
end

function AuctionHouseAuctionsFrameMixin:SetItemKey(itemKey)
	self.itemKey = itemKey;
	self.ItemDisplay:SetItemKey(itemKey);
end

function AuctionHouseAuctionsFrameMixin:GetItemKey()
	return self.itemKey;
end

function AuctionHouseAuctionsFrameMixin:SetDisplayMode(displayMode)
	self.displayMode = displayMode;

	local isAllAuctions = displayMode == AuctionsFrameDisplayMode.AllAuctions;
	self.AllAuctionsList:SetShown(isAllAuctions);
	self.AllAuctionsList:SetSelectedEntry(nil);

	local isBidsList = displayMode == AuctionsFrameDisplayMode.BidsList;
	self.BidsList:SetShown(isBidsList);
	self.BidsList:SetSelectedEntry(nil);

	local isItem = displayMode == AuctionsFrameDisplayMode.Item;
	self.ItemList:SetShown(isItem);
	self.ItemList:SetSelectedEntry(nil);

	local isCommodity = displayMode == AuctionsFrameDisplayMode.Commodity;
	self.CommoditiesList:SetShown(isCommodity);
	self.CommoditiesList:SetSelectedEntry(nil);

	self.ItemDisplay:SetShown(not isAllAuctions and not isBidsList);
end

function AuctionHouseAuctionsFrameMixin:GetDisplayMode()
	return self.displayMode;
end

function AuctionHouseAuctionsFrameMixin:OnSummaryLineSelected(...)
	if self:IsDisplayingBids() then
		self:OnBidSummaryLineSelected(...);
	else
		self:OnAuctionSummaryLineSelected(...);
	end
end

function AuctionHouseAuctionsFrameMixin:OnAuctionSummaryLineSelected(listIndex)
	if listIndex == 1 then
		self:SetItemKey(nil);
		self:SetDisplayMode(AuctionsFrameDisplayMode.AllAuctions);
	else
		local typeIndex = listIndex - 1;
		local itemKey = C_AuctionHouse.GetOwnedAuctionType(typeIndex);
		self:SelectItemKey(itemKey);
	end
end

function AuctionHouseAuctionsFrameMixin:OnBidSummaryLineSelected(listIndex)
	if listIndex == 1 then
		self:SetItemKey(nil);
		self:SetDisplayMode(AuctionsFrameDisplayMode.BidsList);
	else
		local typeIndex = listIndex - 1;
		local itemKey = C_AuctionHouse.GetBidType(typeIndex);
		self:SelectItemKey(itemKey);
	end
end

function AuctionHouseAuctionsFrameMixin:GetSearchContext(displayMode)
	displayMode = displayMode or self:GetDisplayMode();
	if displayMode == AuctionsFrameDisplayMode.Item then
		if self:IsDisplayingBids() then
			return AuctionHouseSearchContext.BidItems;
		else
			return AuctionHouseSearchContext.AuctionsItems;
		end
	elseif displayMode == AuctionsFrameDisplayMode.Commodity then
		return AuctionHouseSearchContext.AuctionsCommodities;
	elseif displayMode == AuctionsFrameDisplayMode.AllAuctions then
		return AuctionHouseSearchContext.AllAuctions;
	elseif displayMode == AuctionsFrameDisplayMode.BidsList then
		return AuctionHouseSearchContext.AllBids;
	end
end

function AuctionHouseAuctionsFrameMixin:SelectItemKey(itemKey)
	local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey);
	if not itemKeyInfo then
		return;
	end

	self:SetItemKey(itemKey);

	local newDisplayMode = itemKeyInfo.isCommodity and AuctionsFrameDisplayMode.Commodity or AuctionsFrameDisplayMode.Item;
	self:GetAuctionHouseFrame():QueryItem(self:GetSearchContext(newDisplayMode), itemKey);
	if itemKeyInfo.isCommodity then
		self.CommoditiesList:SetItemID(itemKey.itemID);
	end
	self:SetDisplayMode(newDisplayMode);
end

function AuctionHouseAuctionsFrameMixin:SelectAuction(auctionID)
	self.selectedAuctionID = auctionID;
	self.CancelAuctionButton:SetEnabled(auctionID ~= nil);
end

function AuctionHouseAuctionsFrameMixin:OnAllAuctionsSearchResultSelected(ownedAuctionInfo)
	self:SelectAuction(ownedAuctionInfo and ownedAuctionInfo.auctionID or nil);
end

function AuctionHouseAuctionsFrameMixin:OnBidsListSearchResultSelected(bidInfo)
	if bidInfo then
		self:SetAuction(bidInfo.auctionID, bidInfo.minBid, bidInfo.buyoutAmount);
	else
		self:SetAuction(nil, nil, nil);
	end
end

function AuctionHouseAuctionsFrameMixin:OnItemSearchResultSelected(itemSearchResultInfo)
	if itemSearchResultInfo then
		local auctionID = itemSearchResultInfo.auctionID;
		if itemSearchResultInfo.containsOwnerItem then
			self:SelectAuction(auctionID);
			self:SetAuction(nil, nil, nil);
		else
			self:SetAuction(auctionID, itemSearchResultInfo.minBid, itemSearchResultInfo.buyoutAmount);
		end
	else
		self:SelectAuction(nil);
		self:SetAuction(nil, nil, nil);
	end
end

function AuctionHouseAuctionsFrameMixin:OnCommoditySearchResultSelected(commoditySearchResultInfo)
	if commoditySearchResultInfo and commoditySearchResultInfo.containsOwnerItem then
		self:SelectAuction(commoditySearchResultInfo.auctionID);
	else
		self:SelectAuction(nil);
	end
end

function AuctionHouseAuctionsFrameMixin:CancelSelectedAuction()
	StaticPopup_Show("CANCEL_AUCTION", nil, nil, { auctionID = self.selectedAuctionID });
end

function AuctionHouseAuctionsFrameMixin:GetTab()
	return PanelTemplates_GetSelectedTab(self);
end

function AuctionHouseAuctionsFrameMixin:SetTab(tabID)
	if self:GetTab() == tabID then
		return;
	end

	PanelTemplates_SetTab(self, tabID);

	local isDisplayingBids = self:IsDisplayingBids();
	
	self.CancelAuctionButton:SetShown(not isDisplayingBids);
	self.BidFrame:SetShown(isDisplayingBids);
	self.BuyoutFrame:SetShown(isDisplayingBids);

	if isDisplayingBids then
		self:GetAuctionHouseFrame():QueryAll(AuctionHouseSearchContext.AllBids);
		self:SetDisplayMode(AuctionsFrameDisplayMode.BidsList);

		local function GetNumBidSummaryResults()
			return C_AuctionHouse.GetNumBidTypes() + 1;
		end

		self.SummaryList:SetGetNumResultsFunction(GetNumBidSummaryResults);
	else
		self:GetAuctionHouseFrame():QueryAll(AuctionHouseSearchContext.AllAuctions);
		self:SetDisplayMode(AuctionsFrameDisplayMode.AllAuctions);
		
		local function GetNumOwnedAuctionSummaryResults()
			return C_AuctionHouse.GetNumOwnedAuctionTypes() + 1;
		end

		self.SummaryList:SetGetNumResultsFunction(GetNumOwnedAuctionSummaryResults);
	end

	self.SummaryList:SetSelectedListIndex(1);
end

function AuctionHouseAuctionsFrameMixin:IsDisplayingBids()
	return self:GetTab() == BIDS_TAB_ID;
end