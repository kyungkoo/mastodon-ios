//
//  AccountListViewModel.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-9-13.
//

import UIKit
import Combine
import CoreData
import CoreDataStack
import MastodonSDK
import MastodonMeta

final class AccountListViewModel {

    var disposeBag = Set<AnyCancellable>()

    // input
    let context: AppContext

    // output
    let authentications = CurrentValueSubject<[Item], Never>([])
    let activeUserID = CurrentValueSubject<Mastodon.Entity.Account.ID?, Never>(nil)
    var diffableDataSource: UITableViewDiffableDataSource<Section, Item>!

    init(context: AppContext) {
        self.context = context

        Publishers.CombineLatest(
            context.authenticationService.mastodonAuthentications,
            context.authenticationService.activeMastodonAuthentication
        )
        .sink { [weak self] authentications, activeAuthentication in
            guard let self = self else { return }
            var items: [Item] = []
            var activeUserID: Mastodon.Entity.Account.ID?
            for authentication in authentications {
                let item = Item.authentication(objectID: authentication.objectID)
                items.append(item)
                if authentication === activeAuthentication {
                    activeUserID = authentication.userID
                }
            }
            self.authentications.value = items
            self.activeUserID.value = activeUserID
        }
        .store(in: &disposeBag)

        authentications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authentications in
                guard let self = self else { return }
                guard let diffableDataSource = self.diffableDataSource else { return }

                var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
                snapshot.appendSections([.main])
                snapshot.appendItems(authentications, toSection: .main)
                snapshot.appendItems([.addAccount], toSection: .main)

                diffableDataSource.apply(snapshot)
            }
            .store(in: &disposeBag)
    }

}

extension AccountListViewModel {
    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case authentication(objectID: NSManagedObjectID)
        case addAccount
    }

    func setupDiffableDataSource(
        tableView: UITableView,
        managedObjectContext: NSManagedObjectContext
    ) {
        diffableDataSource = UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .authentication(let objectID):
                let authentication = managedObjectContext.object(with: objectID) as! MastodonAuthentication
                let user = authentication.user
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AccountListTableViewCell.self), for: indexPath) as! AccountListTableViewCell
                AccountListViewModel.configure(
                    cell: cell,
                    user: user,
                    activeUserID: self.activeUserID.eraseToAnyPublisher()
                )
                return cell
            case .addAccount:
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AddAccountTableViewCell.self), for: indexPath) as! AddAccountTableViewCell
                return cell
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        diffableDataSource?.apply(snapshot)
    }

    static func configure(
        cell: AccountListTableViewCell,
        user: MastodonUser,
        activeUserID: AnyPublisher<Mastodon.Entity.Account.ID?, Never>
    ) {
        // avatar
        cell.configure(with: AvatarConfigurableViewConfiguration(avatarImageURL: user.avatarImageURL()))

        // name
        do {
            let content = MastodonContent(content: user.displayNameWithFallback, emojis: user.emojiMeta)
            let metaContent = try MastodonMetaContent.convert(document: content)
            cell.nameLabel.configure(content: metaContent)
        } catch {
            assertionFailure()
            cell.nameLabel.configure(content: PlaintextMetaContent(string: user.displayNameWithFallback))
        }

        // username
        let usernameMetaContent = PlaintextMetaContent(string: "@" + user.acctWithDomain)
        cell.usernameLabel.configure(content: usernameMetaContent)
        
        // checkmark
        activeUserID
            .receive(on: DispatchQueue.main)
            .sink { userID in
                let isCurrentUser =  user.id == userID
                cell.tintColor = .label
                cell.accessoryType = isCurrentUser ? .checkmark : .none
            }
            .store(in: &cell.disposeBag)
    }
}